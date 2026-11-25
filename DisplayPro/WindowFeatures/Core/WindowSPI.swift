import AppKit
import ApplicationServices
import CoreGraphics
import Darwin

// MARK: - Private window-server / accessibility SPI
//
// None of these symbols are in the public SDK, so — like DisplayManager.swift —
// they are resolved at runtime via dlsym. Each one is optional: when a symbol is
// missing on a given macOS release the caller falls back to public API.
//
//   _AXUIElementGetWindow            AXUIElement → CGWindowID
//   SLSMainConnectionID              connection to the window server
//   SLSCopySpacesForWindows          which Spaces a window lives on
//   GetProcessForPID                 pid → ProcessSerialNumber (deprecated, still exported)
//   _SLPSSetFrontProcessWithOptions  bring a process + specific window to front,
//                                    switching Spaces if needed
//   SLPSPostEventRecordTo            synthesize the "make key window" event
//   SLSSetSymbolicHotKeyEnabled      turn the system ⌘Tab switcher on/off

enum WindowSPI {

    private static let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)

    private static func lookup<T>(_ names: [String], as type: T.Type) -> T? {
        for name in names {
            if let sym = dlsym(rtldDefault, name) {
                return unsafeBitCast(sym, to: type)
            }
        }
        return nil
    }

    private typealias AXGetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias CopySpacesFn = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias GetProcessForPIDFn = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias SetFrontProcessFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    private typealias PostEventRecordFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
    private typealias SetSymbolicHotKeyEnabledFn = @convention(c) (Int32, Bool) -> CGError

    private static let axGetWindow = lookup(["_AXUIElementGetWindow"], as: AXGetWindowFn.self)
    private static let mainConnection = lookup(["SLSMainConnectionID", "CGSMainConnectionID"], as: MainConnectionFn.self)
    private static let copySpaces = lookup(["SLSCopySpacesForWindows", "CGSCopySpacesForWindows"], as: CopySpacesFn.self)
    private static let getProcessForPID = lookup(["GetProcessForPID"], as: GetProcessForPIDFn.self)
    private static let setFrontProcess = lookup(["_SLPSSetFrontProcessWithOptions"], as: SetFrontProcessFn.self)
    private static let postEventRecord = lookup(["SLPSPostEventRecordTo"], as: PostEventRecordFn.self)
    private static let setSymbolicHotKeyEnabled = lookup(
        ["SLSSetSymbolicHotKeyEnabled", "CGSSetSymbolicHotKeyEnabled"],
        as: SetSymbolicHotKeyEnabledFn.self
    )

    // MARK: Window identity

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        guard let fn = axGetWindow else { return nil }
        var id: CGWindowID = 0
        guard fn(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    /// Whether the window is placed on any Space. Windows that are ordered out
    /// (closed-but-retained, background tabs, helper windows) are on none.
    /// Returns `nil` when the SPI is unavailable.
    static func isOnAnySpace(_ id: CGWindowID) -> Bool? {
        guard let mainConnection, let copySpaces else { return nil }
        let cid = mainConnection()
        let ids = [NSNumber(value: id)] as CFArray
        // Mask 0x7 = current | other | user Spaces.
        guard let spaces = copySpaces(cid, 0x7, ids)?.takeRetainedValue() as? [NSNumber] else {
            return false
        }
        return !spaces.isEmpty
    }

    // MARK: Focus

    /// Brings `windowID` of process `pid` to the front and makes it key,
    /// switching to its Space if necessary.
    /// - Returns: `false` if the SPI is unavailable (caller should fall back).
    @discardableResult
    static func bringToFront(pid: pid_t, windowID: CGWindowID) -> Bool {
        guard let getProcessForPID, let setFrontProcess, let postEventRecord else { return false }

        var psn = ProcessSerialNumber()
        guard getProcessForPID(pid, &psn) == noErr else { return false }

        // 0x200 = kCPSUserGenerated
        guard setFrontProcess(&psn, windowID, 0x200) == .success else { return false }

        // Synthesized "make key window" event record (layout as used by AltTab).
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        var wid = windowID
        withUnsafeBytes(of: &wid) { raw in
            for (i, b) in raw.enumerated() { bytes[0x3c + i] = b }
        }
        for i in 0x20..<0x30 { bytes[i] = 0xff }

        bytes[0x08] = 0x01
        _ = postEventRecord(&psn, &bytes)
        bytes[0x08] = 0x02
        _ = postEventRecord(&psn, &bytes)
        return true
    }

    // MARK: System ⌘Tab

    /// Symbolic hot-key ids of the system app switcher.
    private static let commandTabHotKeys: [Int32] = [
        1, // ⌘Tab
        2, // ⌘⇧Tab
        6, // ⌘` (key above Tab)
    ]

    /// Enables or disables the built-in ⌘Tab switcher. The window server
    /// consumes these shortcuts before any event tap sees them, so they must be
    /// turned off for our own switcher to receive ⌘Tab.
    static func setNativeCommandTabEnabled(_ enabled: Bool) {
        guard let setSymbolicHotKeyEnabled else { return }
        for key in commandTabHotKeys {
            _ = setSymbolicHotKeyEnabled(key, enabled)
        }
    }

    static var canOverrideCommandTab: Bool { setSymbolicHotKeyEnabled != nil }
}
