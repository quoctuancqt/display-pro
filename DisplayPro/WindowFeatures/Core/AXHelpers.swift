import AppKit
import ApplicationServices

/// Thin wrappers over the Accessibility C API.
enum AXHelpers {

    /// Application element with a short messaging timeout, so a hung app
    /// can't stall the switcher or the Dock preview.
    static func application(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        return element
    }

    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        (value(element, attribute) as? NSNumber)?.boolValue
    }

    static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        (value(element, attribute) as? [AXUIElement]) ?? []
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let v = value(element, attribute), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    static func url(_ element: AXUIElement, _ attribute: String) -> URL? {
        guard let v = value(element, attribute) else { return nil }
        if let url = v as? URL { return url }
        if let s = v as? String { return URL(string: s) }
        return nil
    }

    /// Frame in CoreGraphics global coordinates (top-left origin).
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let posValue = value(element, kAXPositionAttribute as String),
              let sizeValue = value(element, kAXSizeAttribute as String),
              CFGetTypeID(posValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    // MARK: Windows

    struct AXWindow {
        let element: AXUIElement
        let id: CGWindowID
        let title: String?
        let isMinimized: Bool
    }

    /// The windows AX reports for an app: those on the current Space plus
    /// minimized ones. Windows on other Spaces are not included.
    static func windows(pid: pid_t) -> [AXWindow] {
        let app = application(pid)
        return elements(app, kAXWindowsAttribute as String).compactMap { el in
            guard let id = WindowSPI.windowID(of: el) else { return nil }
            return AXWindow(
                element: el,
                id: id,
                title: string(el, kAXTitleAttribute as String),
                isMinimized: bool(el, kAXMinimizedAttribute as String) ?? false
            )
        }
    }

    static func window(pid: pid_t, id: CGWindowID) -> AXUIElement? {
        windows(pid: pid).first { $0.id == id }?.element
    }

    static func focusedWindowID(pid: pid_t) -> CGWindowID? {
        guard let el = element(application(pid), kAXFocusedWindowAttribute as String) else { return nil }
        return WindowSPI.windowID(of: el)
    }
}
