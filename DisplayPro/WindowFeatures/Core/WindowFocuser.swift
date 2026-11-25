import AppKit
import ApplicationServices

/// Brings a specific window to the front, wherever it is.
enum WindowFocuser {

    static func focus(_ window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }

        if app.isHidden { app.unhide() }

        let axWindow = AXHelpers.window(pid: window.pid, id: window.id)

        if window.placement == .minimized, let axWindow {
            AXUIElementSetAttributeValue(axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        // The SkyLight path focuses the exact window and switches Spaces for
        // windows that aren't on the current one; activating the app alone
        // would only bring forward its most recent window.
        if !WindowSPI.bringToFront(pid: window.pid, windowID: window.id) {
            app.activate()
        }

        if let axWindow {
            AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        }
    }
}
