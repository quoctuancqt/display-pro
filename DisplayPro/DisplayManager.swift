import Foundation
import CoreGraphics
import AppKit
import Darwin

// MARK: - SPI bridging
//
// CoreGraphics' display-config SPI is not in the Swift overlay or SDK .tbd
// stubs, so we resolve it dynamically via dyld. The names also drifted over
// time:
//
//   macOS  ≤ 25:  CGConfigureDisplayEnabled,   CGRestoreAllDisplayConfigurations
//   macOS  ≥ 26:  CGSConfigureDisplayEnabled,  CGRestorePermanentDisplayConfiguration
//
// We try the new names first (since this app targets recent macOS) and fall
// back to the old names for earlier releases. Both pairs share the same C
// signature; the underlying implementation lives in SkyLight.framework.

private typealias _CGConfigureDisplayEnabledFn = @convention(c) (
    CGDisplayConfigRef?, CGDirectDisplayID, boolean_t
) -> CGError

private typealias _CGRestoreFn = @convention(c) () -> Void

private let _RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)

private func _lookup<T>(_ names: [String], as type: T.Type) -> T? {
    for name in names {
        if let sym = dlsym(_RTLD_DEFAULT, name) {
            return unsafeBitCast(sym, to: type)
        }
    }
    return nil
}

private let _CGConfigureDisplayEnabled: _CGConfigureDisplayEnabledFn? =
    _lookup(["CGSConfigureDisplayEnabled", "CGConfigureDisplayEnabled"],
            as: _CGConfigureDisplayEnabledFn.self)

private let _CGRestoreDisplayConfiguration: _CGRestoreFn? =
    _lookup(["CGRestorePermanentDisplayConfiguration", "CGRestoreAllDisplayConfigurations"],
            as: _CGRestoreFn.self)

/// Forces the system to re-detect attached displays — same path the
/// "Detect Displays" button in System Settings invokes.
private let _CGSDetectDisplays: _CGRestoreFn? =
    _lookup(["CGSDetectDisplays"], as: _CGRestoreFn.self)

// MARK: - Models

struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let isMain: Bool
    let isActive: Bool
    let isOnline: Bool
    let width: Int
    let height: Int
}

private struct KnownDisplay: Codable {
    let id: UInt32
    var name: String
    var width: Int
    var height: Int
    var softDisabled: Bool
}

// MARK: - Persistence
//
// Soft-disabled displays drop out of CGGetOnlineDisplayList, so we'd have no
// way to surface them in the menu (or re-enable them) without remembering
// them ourselves. We persist enough metadata to render the row and the
// CGDirectDisplayID so we can target it again. The ID is derived from EDID
// on Apple Silicon and is stable across reboots for the same hardware.

private final class DisplayMemory {
    // Bumped to v2 to discard stale phantom-display entries an earlier build
    // captured from CGSGetDisplayList.
    private let key = "DisplayPro.knownDisplays.v2"
    private let defaults = UserDefaults.standard

    func load() -> [UInt32: KnownDisplay] {
        guard let data = defaults.data(forKey: key),
              let arr = try? JSONDecoder().decode([KnownDisplay].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: arr.map { ($0.id, $0) })
    }

    func save(_ map: [UInt32: KnownDisplay]) {
        let arr = Array(map.values)
        if let data = try? JSONEncoder().encode(arr) {
            defaults.set(data, forKey: key)
        }
    }
}

// MARK: - Manager

@MainActor
final class DisplayManager: ObservableObject {

    @Published private(set) var displays: [DisplayInfo] = []
    @Published var lastError: String?

    private let memory = DisplayMemory()
    private var known: [UInt32: KnownDisplay] = [:]
    private var reconfigCallbackInstalled = false

    init() {
        known = memory.load()
        installReconfigurationCallback()
        refresh()
    }

    // MARK: - Enumeration

    func refresh() {
        let onlineIDs = Self.fetchOnlineDisplayIDs()
        let main = CGMainDisplayID()

        var rows: [DisplayInfo] = []

        // 1. Online displays — always shown. Refresh memory with their
        //    current name/size and clear any stale soft-disabled flag.
        for id in onlineIDs {
            let key = UInt32(id)
            let name = Self.displayName(for: id)
            let width = Int(CGDisplayPixelsWide(id))
            let height = Int(CGDisplayPixelsHigh(id))
            known[key] = KnownDisplay(
                id: key, name: name, width: width, height: height, softDisabled: false
            )
            rows.append(DisplayInfo(
                id: id,
                name: name,
                isMain: id == main,
                isActive: CGDisplayIsActive(id) != 0,
                isOnline: true,
                width: width,
                height: height
            ))
        }

        // 2. Offline displays — only show if we have a real memory entry that
        //    we marked soft-disabled ourselves. Skips phantom IDs that
        //    `CGSGetDisplayList` reports for mirror targets, AirPlay slots,
        //    and similar virtual displays.
        let onlineSet = Set(onlineIDs)
        for entry in known.values
            where entry.softDisabled && !onlineSet.contains(CGDirectDisplayID(entry.id))
        {
            rows.append(DisplayInfo(
                id: CGDirectDisplayID(entry.id),
                name: entry.name,
                isMain: false,
                isActive: false,
                isOnline: false,
                width: entry.width,
                height: entry.height
            ))
        }

        memory.save(known)

        rows.sort { lhs, rhs in
            if lhs.isMain != rhs.isMain { return lhs.isMain }
            if lhs.isOnline != rhs.isOnline { return lhs.isOnline }
            return lhs.id < rhs.id
        }
        displays = rows
    }

    /// IDs from `CGGetOnlineDisplayList` — currently-online displays only.
    private static func fetchOnlineDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    // MARK: - Soft connect / disconnect

    /// Enable or disable a single display permanently. The change persists
    /// across reboots until restored or toggled back on.
    func setEnabled(_ enabled: Bool, for displayID: CGDirectDisplayID) {
        guard let configureEnabled = _CGConfigureDisplayEnabled else {
            lastError = "CGConfigureDisplayEnabled is unavailable on this OS."
            return
        }

        var config: CGDisplayConfigRef?
        var err = CGBeginDisplayConfiguration(&config)
        guard err == .success, let config else {
            report("CGBeginDisplayConfiguration failed", err)
            return
        }

        let flag: boolean_t = enabled ? 1 : 0
        err = configureEnabled(config, displayID, flag)
        guard err == .success else {
            CGCancelDisplayConfiguration(config)
            report("CGConfigureDisplayEnabled failed", err)
            return
        }

        err = CGCompleteDisplayConfiguration(config, .permanently)
        guard err == .success else {
            report("CGCompleteDisplayConfiguration failed", err)
            return
        }

        // Update memory: track the disabled state so we can render the row
        // even after the display drops out of the online list.
        let key = UInt32(displayID)
        if var entry = known[key] {
            entry.softDisabled = !enabled
            known[key] = entry
        } else if !enabled {
            // First time we touch this display and we're disabling it — capture
            // a snapshot before it disappears from the online list.
            known[key] = KnownDisplay(
                id: key,
                name: Self.displayName(for: displayID),
                width: Int(CGDisplayPixelsWide(displayID)),
                height: Int(CGDisplayPixelsHigh(displayID)),
                softDisabled: true
            )
        }
        memory.save(known)

        refresh()
    }

    func toggle(_ display: DisplayInfo) {
        setEnabled(!display.isActive, for: display.id)
    }

    // MARK: - Safety: reconnect everything

    /// Restores user-defaults display state, then re-enables any displays we
    /// remember as soft-disabled by walking them one-at-a-time. Per-display
    /// sessions avoid the `kCGErrorRangeCheck` (1001) that a bulk
    /// `CGCompleteDisplayConfiguration` triggers when nothing meaningful
    /// changed.
    func reconnectAll() {
        // 1. Force the system to re-detect attached hardware. Does the same
        //    thing as the "Detect Displays" button in System Settings.
        _CGSDetectDisplays?()

        // 2. Restore from the user-defaults snapshot (no-op for displays we
        //    permanently disabled, but cheap and idempotent).
        _CGRestoreDisplayConfiguration?()

        // 3. Walk every display the system knows about (via CGSGetDisplayList)
        //    and re-enable any that aren't currently online — these are the
        //    soft-disabled ones our toggles created.
        refresh()
        let stillOffline = displays.filter { !$0.isOnline }
        for display in stillOffline {
            setEnabled(true, for: display.id)
        }
        refresh()
    }

    // MARK: - Permissions

    /// `CGConfigureDisplayEnabled` itself does not require Screen Recording
    /// permission, but some sibling Quartz APIs (notably anything that reads
    /// pixel data) do. Provided here for callers that want to surface a
    /// pre-flight prompt.
    static func hasScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    @discardableResult
    static func requestScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGRequestScreenCaptureAccess()
        }
        return true
    }

    // MARK: - Display name resolution

    private static func displayName(for id: CGDirectDisplayID) -> String {
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            if let screenID = screen.deviceDescription[key] as? CGDirectDisplayID,
               screenID == id {
                return screen.localizedName
            }
        }
        return "Display \(id)"
    }

    // MARK: - Hot-plug callback

    private func installReconfigurationCallback() {
        guard !reconfigCallbackInstalled else { return }
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        let err = CGDisplayRegisterReconfigurationCallback({ _, flags, userInfo in
            guard let userInfo else { return }
            let manager = Unmanaged<DisplayManager>.fromOpaque(userInfo).takeUnretainedValue()
            let interesting: CGDisplayChangeSummaryFlags = [
                .addFlag, .removeFlag, .enabledFlag, .disabledFlag, .setMainFlag
            ]
            if !flags.intersection(interesting).isEmpty {
                Task { @MainActor in manager.refresh() }
            }
        }, opaque)
        if err == .success { reconfigCallbackInstalled = true }
    }

    // MARK: - Helpers

    private func report(_ message: String, _ err: CGError) {
        lastError = "\(message) (CGError \(err.rawValue))"
    }
}
