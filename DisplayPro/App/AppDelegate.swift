import AppKit
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure we're an accessory app (no Dock icon) — belt-and-suspenders with LSUIElement
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Nothing to clean up — DisplayObserver deinit handles CGDisplay callback removal
    }
}
