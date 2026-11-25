import AppKit
import ApplicationServices

/// Watches which Dock icon the pointer is over.
///
/// The Dock exposes its icons as children of an `AXList`; hovering an icon
/// changes the list's selected children, which posts
/// `kAXSelectedChildrenChangedNotification`.
@MainActor
final class DockObserver {

    struct Item {
        let app: NSRunningApplication?
        let title: String
        /// Icon frame in CoreGraphics global coordinates.
        let frame: CGRect
    }

    /// Called with the hovered item, or `nil` when the pointer leaves the icons.
    var onHover: ((Item?) -> Void)?

    private var observer: AXObserver?
    private var list: AXUIElement?
    private var launchObserver: NSObjectProtocol?

    var isRunning: Bool { observer != nil }

    @discardableResult
    func start() -> Bool {
        guard observer == nil else { return true }
        guard attach() else { return false }

        // Re-attach when the Dock restarts (e.g. `killall Dock`, settings change).
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == "com.apple.dock" else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                self.detach()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    MainActor.assumeIsolated { _ = self.attach() }
                }
            }
        }
        return true
    }

    func stop() {
        if let launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        }
        launchObserver = nil
        detach()
    }

    // MARK: Attach

    private func attach() -> Bool {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return false
        }
        let pid = dock.processIdentifier
        let dockElement = AXHelpers.application(pid)
        guard let list = AXHelpers.elements(dockElement, kAXChildrenAttribute as String)
            .first(where: { AXHelpers.string($0, kAXRoleAttribute as String) == kAXListRole as String })
        else {
            windowFeaturesLog.error("Dock AXList not found")
            return false
        }

        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let me = Unmanaged<DockObserver>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { me.selectionChanged() }
        }

        var obs: AXObserver?
        guard AXObserverCreate(pid, callback, &obs) == .success, let obs else { return false }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(obs, list, kAXSelectedChildrenChangedNotification as CFString, refcon) == .success else {
            windowFeaturesLog.error("Could not observe Dock selection")
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)

        observer = obs
        self.list = list
        return true
    }

    private func detach() {
        if let observer {
            if let list {
                AXObserverRemoveNotification(observer, list, kAXSelectedChildrenChangedNotification as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        list = nil
    }

    // MARK: Selection

    private func selectionChanged() {
        guard let list else { return }
        guard let selected = AXHelpers.elements(list, kAXSelectedChildrenAttribute as String).first,
              let frame = AXHelpers.frame(selected)
        else {
            onHover?(nil)
            return
        }

        let subrole = AXHelpers.string(selected, kAXSubroleAttribute as String)
        guard subrole == "AXApplicationDockItem" else {
            // Folders, trash, minimized-window tiles, separators…
            onHover?(nil)
            return
        }

        let title = AXHelpers.string(selected, kAXTitleAttribute as String) ?? ""
        var app: NSRunningApplication?
        if let url = AXHelpers.url(selected, kAXURLAttribute as String) {
            let path = url.standardizedFileURL.path
            app = NSWorkspace.shared.runningApplications.first {
                $0.bundleURL?.standardizedFileURL.path == path
            }
        }
        if app == nil {
            app = NSWorkspace.shared.runningApplications.first {
                $0.activationPolicy == .regular && $0.localizedName == title
            }
        }

        onHover?(Item(app: app, title: title, frame: frame))
    }
}
