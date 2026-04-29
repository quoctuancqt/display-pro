import CoreGraphics

// Load DisplayServices before accessing symbols
private let _displayServicesHandle: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
    RTLD_NOW
)

@_silgen_name("DisplayServicesSetBrightness")
func DisplayServicesSetBrightness(_ displayID: CGDirectDisplayID, _ brightness: Float) -> Int32

@_silgen_name("DisplayServicesGetBrightness")
func DisplayServicesGetBrightness(_ displayID: CGDirectDisplayID, _ brightness: UnsafeMutablePointer<Float>) -> Int32

// XDR/HDR boost — values above 1.0 unlock HDR headroom (up to ~1.6 = 1600 nits)
@_silgen_name("DisplayServicesSetMaximumPotentialBrightness")
func DisplayServicesSetMaximumPotentialBrightness(_ displayID: CGDirectDisplayID, _ brightness: Float) -> Int32

@_silgen_name("DisplayServicesGetMaximumPotentialBrightness")
func DisplayServicesGetMaximumPotentialBrightness(_ displayID: CGDirectDisplayID, _ brightness: UnsafeMutablePointer<Float>) -> Int32

@_silgen_name("DisplayServicesCanChangeBrightness")
func DisplayServicesCanChangeBrightness(_ displayID: CGDirectDisplayID) -> Bool

@_silgen_name("DisplayServicesHasAmbientLightCompensation")
func DisplayServicesHasAmbientLightCompensation(_ displayID: CGDirectDisplayID) -> Bool

@_silgen_name("DisplayServicesIsSmartDisplay")
func DisplayServicesIsSmartDisplay(_ displayID: CGDirectDisplayID) -> Bool
