import AppKit
import CoreGraphics
import OSLog

let windowFeaturesLog = Logger(subsystem: "com.displaypro.app", category: "windows")

/// A user-facing window, as shown in the Dock preview and the ⌘Tab switcher.
struct WindowInfo: Identifiable, Hashable {

    enum Placement: Hashable {
        case visible        // on screen, on the current Space
        case otherSpace     // on a Space that isn't showing
        case minimized
        case hidden         // owning app is hidden (⌘H)
    }

    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    /// Frame in CoreGraphics global coordinates (top-left origin).
    let frame: CGRect
    let placement: Placement
    /// Name of the display the window is on (set only with 2+ displays).
    let displayName: String?

    var displayTitle: String { title.isEmpty ? appName : title }

    var icon: NSImage? { NSRunningApplication(processIdentifier: pid)?.icon }

    var badge: String? {
        switch placement {
        case .visible: return displayName
        case .otherSpace: return displayName.map { "Other Space · \($0)" } ?? "Other Space"
        case .minimized: return "Minimized"
        case .hidden: return "Hidden"
        }
    }
}

// MARK: - Coordinate helpers

enum ScreenGeometry {

    /// Height of the primary screen, the anchor of both coordinate systems.
    static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    /// CoreGraphics (top-left origin) → Cocoa (bottom-left origin).
    static func cocoa(fromCG rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Screen with the largest overlap with a Cocoa-space rect.
    static func screen(for cocoaRect: CGRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            area(a.frame.intersection(cocoaRect)) < area(b.frame.intersection(cocoaRect))
        }.flatMap { area($0.frame.intersection(cocoaRect)) > 0 ? $0 : nil }
    }

    static var screenUnderMouse: NSScreen {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private static func area(_ r: CGRect) -> CGFloat {
        r.isNull ? 0 : r.width * r.height
    }
}
