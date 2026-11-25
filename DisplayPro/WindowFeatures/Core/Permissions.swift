import AppKit
import ApplicationServices
import CoreGraphics

/// Accessibility (Dock AX, ⌘Tab event tap, raising windows) and
/// Screen Recording (window thumbnails and titles) permission helpers.
enum Permissions {

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static var hasScreenRecording: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows the system Accessibility prompt (only the first time) and opens
    /// the matching pane in System Settings.
    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            openSettings(anchor: "Privacy_Accessibility")
        }
    }

    static func requestScreenRecording() {
        if !CGRequestScreenCaptureAccess() {
            openSettings(anchor: "Privacy_ScreenCapture")
        }
    }

    private static func openSettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
