import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// Intercepts ⌘Tab (and the keys used while the switcher is open) with a
/// session event tap. Requires Accessibility permission.
///
/// The system's own ⌘Tab is a window-server symbolic hot key that fires before
/// any event tap, so it is disabled while this tap is installed and restored
/// when it is removed.
@MainActor
final class SwitcherHotkeyTap {

    enum Action {
        case begin(reverse: Bool)
        case next
        case previous
        case up
        case down
        case commit
        case cancel
    }

    /// Set while the switcher is open. The controller resets it on commit/cancel.
    var isActive = false
    var onAction: ((Action) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isInstalled: Bool { tap != nil }

    @discardableResult
    func install() -> Bool {
        guard tap == nil else { return true }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<SwitcherHotkeyTap>.fromOpaque(refcon).takeUnretainedValue()
            let swallow = MainActor.assumeIsolated { me.handle(type: type, event: event) }
            return swallow ? nil : Unmanaged.passUnretained(event)
        }

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            windowFeaturesLog.error("Could not create ⌘Tab event tap (Accessibility not granted?)")
            return false
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        source = src

        WindowSPI.setNativeCommandTabEnabled(false)
        return true
    }

    func uninstall() {
        WindowSPI.setNativeCommandTabEnabled(true)
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        isActive = false
    }

    // MARK: Event handling

    /// - Returns: `true` to swallow the event.
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false

        case .flagsChanged:
            if isActive && !event.flags.contains(.maskCommand) {
                send(.commit)
            }
            return false

        case .keyDown:
            let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let command = flags.contains(.maskCommand)
            let shift = flags.contains(.maskShift)

            if command && key == kVK_Tab {
                if isActive {
                    send(shift ? .previous : .next)
                } else {
                    isActive = true
                    send(.begin(reverse: shift))
                }
                return true
            }

            guard isActive else { return false }

            switch key {
            case kVK_ANSI_Grave: send(.previous)
            case kVK_LeftArrow: send(.previous)
            case kVK_RightArrow: send(.next)
            case kVK_UpArrow: send(.up)
            case kVK_DownArrow: send(.down)
            case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space: send(.commit)
            case kVK_Escape: send(.cancel)
            default: break
            }
            // While open, keystrokes belong to the switcher.
            return true

        case .keyUp:
            let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
            return isActive || (key == kVK_Tab && event.flags.contains(.maskCommand))

        default:
            return false
        }
    }

    /// Dispatches asynchronously so the tap callback returns immediately and
    /// the window server never times the tap out.
    private func send(_ action: Action) {
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.onAction?(action) }
        }
    }
}
