import Foundation
import IOKit.pwr_mgt

/// Holds an IOKit power assertion that prevents the display from sleeping.
///
/// The assertion lives for as long as it is held; releasing it lets macOS resume
/// its normal idle-sleep timing. The assertion is process-scoped, so it also goes
/// away automatically when the app quits.
final class WakeController {
    private var assertionID: IOPMAssertionID = IOPMAssertionID(0)

    private(set) var isActive: Bool = false

    deinit {
        _ = release()
    }

    /// Turns the display-sleep assertion on or off.
    /// - Returns: `true` if the controller ended up in the requested state.
    @discardableResult
    func setKeepAwake(_ enabled: Bool) -> Bool {
        enabled ? acquire() : release()
    }

    private func acquire() -> Bool {
        guard !isActive else { return true }

        var id = IOPMAssertionID(0)
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "DisplayPro — Keep Screen Awake" as CFString,
            &id
        )

        guard status == kIOReturnSuccess else { return false }

        assertionID = id
        isActive = true
        return true
    }

    private func release() -> Bool {
        guard isActive else { return true }

        let status = IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(0)
        isActive = false
        return status == kIOReturnSuccess
    }
}
