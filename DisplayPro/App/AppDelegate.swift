import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure we're an accessory app (no Dock icon) — belt-and-suspenders with LSUIElement
        NSApp.setActivationPolicy(.accessory)

        // Dock Preview and the ⌘Tab window switcher.
        WindowFeatures.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Restore the system ⌘Tab switcher. DisplayObserver deinit handles CGDisplay callback removal.
        WindowFeatures.shared.stop()
    }
}
