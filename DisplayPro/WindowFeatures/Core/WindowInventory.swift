import AppKit
import CoreGraphics

/// Enumerates user windows across all Spaces and displays, ordered
/// most-recently-used first.
@MainActor
final class WindowInventory {

    /// Window ids, most recently focused first.
    private var mru: [CGWindowID] = []
    private var activationObserver: NSObjectProtocol?

    init() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, let app else { return }
                // Give the app a beat to settle its focused window.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    MainActor.assumeIsolated { self.noteFocusedWindow(of: app.processIdentifier) }
                }
            }
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    // MARK: MRU

    func noteFocused(_ id: CGWindowID) {
        mru.removeAll { $0 == id }
        mru.insert(id, at: 0)
        if mru.count > 512 { mru.removeLast(mru.count - 512) }
    }

    func noteFocusedWindow(of pid: pid_t) {
        guard Permissions.hasAccessibility, let id = AXHelpers.focusedWindowID(pid: pid) else { return }
        noteFocused(id)
    }

    // MARK: Enumeration

    func windows(forPID pid: pid_t) -> [WindowInfo] {
        enumerate(onlyPID: pid)
    }

    func allWindows() -> [WindowInfo] {
        if let front = NSWorkspace.shared.frontmostApplication {
            noteFocusedWindow(of: front.processIdentifier)
        }
        return enumerate(onlyPID: nil)
    }

    private func enumerate(onlyPID: pid_t?) -> [WindowInfo] {
        let ownPID = ProcessInfo.processInfo.processIdentifier

        var apps: [pid_t: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != ownPID {
            if let onlyPID, app.processIdentifier != onlyPID { continue }
            apps[app.processIdentifier] = app
        }
        guard !apps.isEmpty else { return [] }

        guard let raw = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return [] }

        let showDisplayNames = NSScreen.screens.count > 1
        var axCache: [pid_t: [CGWindowID: AXHelpers.AXWindow]] = [:]
        let hasAX = Permissions.hasAccessibility

        func axWindows(_ pid: pid_t) -> [CGWindowID: AXHelpers.AXWindow] {
            if let cached = axCache[pid] { return cached }
            let map = hasAX
                ? Dictionary(AXHelpers.windows(pid: pid).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                : [:]
            axCache[pid] = map
            return map
        }

        var result: [(info: WindowInfo, z: Int)] = []
        var seen = Set<CGWindowID>()

        for (z, entry) in raw.enumerated() {
            guard let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  !seen.contains(id),
                  let pidNum = entry[kCGWindowOwnerPID as String] as? Int,
                  let app = apps[pid_t(pidNum)],
                  (entry[kCGWindowLayer as String] as? Int) == 0,
                  ((entry[kCGWindowAlpha as String] as? Double) ?? 1) > 0,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width >= 50, bounds.height >= 50
            else { continue }

            let pid = pid_t(pidNum)
            let isOnScreen = (entry[kCGWindowIsOnscreen as String] as? Bool) ?? false
            let ax = axWindows(pid)[id]
            var title = (entry[kCGWindowName as String] as? String) ?? ""
            if title.isEmpty { title = ax?.title ?? "" }

            let placement: WindowInfo.Placement
            if ax?.isMinimized == true {
                placement = .minimized
            } else if app.isHidden {
                // Hidden apps' windows are ordered out; keep the ones AX knows
                // about, or that are titled, so they don't vanish from the list.
                guard ax != nil || !title.isEmpty else { continue }
                placement = .hidden
            } else if isOnScreen {
                placement = .visible
            } else {
                // Off-screen and not minimized: either on another Space, or an
                // ordered-out helper/tab window that the user can't see.
                if let onSpace = WindowSPI.isOnAnySpace(id) {
                    guard onSpace else { continue }
                } else {
                    guard !title.isEmpty else { continue }
                }
                placement = .otherSpace
            }

            // AX knows the windows of the current Space; on-screen windows it
            // doesn't list are usually overlays (e.g. drag images, popovers).
            if hasAX, placement == .visible, ax == nil, !axWindows(pid).isEmpty, title.isEmpty {
                continue
            }

            seen.insert(id)
            let displayName = showDisplayNames
                ? ScreenGeometry.screen(for: ScreenGeometry.cocoa(fromCG: bounds))?.localizedName
                : nil

            result.append((
                WindowInfo(
                    id: id,
                    pid: pid,
                    appName: app.localizedName ?? "",
                    title: title,
                    frame: bounds,
                    placement: placement,
                    displayName: displayName
                ),
                z
            ))
        }

        let rank = Dictionary(mru.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return result
            .sorted { a, b in
                switch (rank[a.info.id], rank[b.info.id]) {
                case let (ra?, rb?): return ra < rb
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil):
                    // Minimized / hidden windows go last among unranked ones.
                    let wa = a.info.placement == .minimized || a.info.placement == .hidden
                    let wb = b.info.placement == .minimized || b.info.placement == .hidden
                    if wa != wb { return !wa }
                    return a.z < b.z
                }
            }
            .map(\.info)
    }
}
