import Combine
import CoreGraphics
import Foundation

struct DisplayChangeEvent {
    let displayID: CGDirectDisplayID
    let flags: CGDisplayChangeSummaryFlags
}

@MainActor
final class DisplayObserver: ObservableObject {
    let displayChanged = PassthroughSubject<DisplayChangeEvent, Never>()

    private var callbackRegistered = false

    init() {
        let userInfo = Unmanaged.passRetained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback(displayReconfigCallback, userInfo)
        callbackRegistered = true
    }

    deinit {
        if callbackRegistered {
            let userInfo = Unmanaged.passUnretained(self).toOpaque()
            CGDisplayRemoveReconfigurationCallback(displayReconfigCallback, userInfo)
        }
    }
}

// Top-level C-compatible callback — must be a free function
private func displayReconfigCallback(
    display: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags,
    userInfo: UnsafeMutableRawPointer?
) {
    guard let ptr = userInfo else { return }
    let observer = Unmanaged<DisplayObserver>.fromOpaque(ptr).takeUnretainedValue()
    Task { @MainActor in
        observer.displayChanged.send(DisplayChangeEvent(displayID: display, flags: flags))
    }
}
