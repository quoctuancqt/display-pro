import CoreGraphics
import Foundation
import IOKit

struct DisplayHardware: Equatable {
    let displayID: CGDirectDisplayID
    let isBuiltIn: Bool
    let isOnline: Bool
    let isActive: Bool
    let isMirrored: Bool
    let vendorNumber: UInt32
    let modelNumber: UInt32
    let serialNumber: UInt32
    let screenSize: CGSize       // logical points
    let physicalSize: CGSize     // millimeters
    let supportsHDR: Bool
    let supportsXDR: Bool
    let hasDDC: Bool
    let isAppleSilicon: Bool

    static func query(displayID: CGDirectDisplayID, ddcService: DDCServiceProtocol) -> DisplayHardware {
        let bounds = CGDisplayBounds(displayID)
        let mmSize = CGDisplayScreenSize(displayID)
        let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0

        // XDR/HDR capability: check DisplayServices
        let canChangeBrightness = DisplayServicesCanChangeBrightness(displayID)
        var maxBrightness: Float = 0
        _ = DisplayServicesGetMaximumPotentialBrightness(displayID, &maxBrightness)
        let supportsXDR = maxBrightness > 1.0 && canChangeBrightness

        return DisplayHardware(
            displayID: displayID,
            isBuiltIn: isBuiltIn,
            isOnline: CGDisplayIsOnline(displayID) != 0,
            isActive: CGDisplayIsActive(displayID) != 0,
            isMirrored: CGDisplayIsInMirrorSet(displayID) != 0,
            vendorNumber: CGDisplayVendorNumber(displayID),
            modelNumber: CGDisplayModelNumber(displayID),
            serialNumber: CGDisplaySerialNumber(displayID),
            screenSize: CGSize(width: bounds.width, height: bounds.height),
            physicalSize: CGSize(width: mmSize.width, height: mmSize.height),
            supportsHDR: canChangeBrightness,
            supportsXDR: supportsXDR,
            hasDDC: !isBuiltIn && ddcService.isSupported(displayID: displayID),
            isAppleSilicon: DDCService.isAppleSilicon
        )
    }
}
