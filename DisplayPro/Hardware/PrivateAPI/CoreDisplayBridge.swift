import CoreGraphics

// Load CoreDisplay before accessing symbols
private let _coreDisplayHandle: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay",
    RTLD_NOW
)

@_silgen_name("CoreDisplay_Display_SetUserBrightness")
func CoreDisplay_Display_SetUserBrightness(_ displayID: CGDirectDisplayID, _ brightness: Double)

@_silgen_name("CoreDisplay_Display_GetUserBrightness")
func CoreDisplay_Display_GetUserBrightness(_ displayID: CGDirectDisplayID) -> Double

@_silgen_name("CoreDisplay_Display_SetLinearBrightness")
func CoreDisplay_Display_SetLinearBrightness(_ displayID: CGDirectDisplayID, _ brightness: Double)

@_silgen_name("CoreDisplay_Display_GetLinearBrightness")
func CoreDisplay_Display_GetLinearBrightness(_ displayID: CGDirectDisplayID) -> Double

@_silgen_name("CoreDisplay_Display_SetDisplayGammaTable")
func CoreDisplay_Display_SetDisplayGammaTable(
    _ displayID: CGDirectDisplayID,
    _ capacity: Int32,
    _ red: UnsafePointer<Float>,
    _ green: UnsafePointer<Float>,
    _ blue: UnsafePointer<Float>
)
