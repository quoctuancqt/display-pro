import CoreGraphics
import Foundation

// CGVirtualDisplay is a semi-public framework (macOS 12.4+)
// Used for creating virtual displays with custom HiDPI resolutions
private let _cgVirtualDisplayHandle: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/Frameworks/CGVirtualDisplay.framework/CGVirtualDisplay",
    RTLD_NOW
)

// Opaque reference types
typealias CGVirtualDisplayRef = OpaquePointer
typealias CGVirtualDisplayDescriptorRef = OpaquePointer
typealias CGVirtualDisplaySettingsRef = OpaquePointer
typealias CGVirtualDisplayModeDescriptorRef = OpaquePointer

@_silgen_name("CGVirtualDisplayCreate")
func CGVirtualDisplayCreate(
    _ descriptor: CGVirtualDisplayDescriptorRef,
    _ settings: CGVirtualDisplaySettingsRef,
    _ displayID: UnsafeMutablePointer<CGDirectDisplayID>
) -> CGVirtualDisplayRef?

@_silgen_name("CGVirtualDisplayDescriptorCreate")
func CGVirtualDisplayDescriptorCreate() -> CGVirtualDisplayDescriptorRef?

@_silgen_name("CGVirtualDisplayDescriptorSetMaxPixelsWide")
func CGVirtualDisplayDescriptorSetMaxPixelsWide(_ descriptor: CGVirtualDisplayDescriptorRef, _ width: UInt32)

@_silgen_name("CGVirtualDisplayDescriptorSetMaxPixelsHigh")
func CGVirtualDisplayDescriptorSetMaxPixelsHigh(_ descriptor: CGVirtualDisplayDescriptorRef, _ height: UInt32)

@_silgen_name("CGVirtualDisplayDescriptorSetSizeInMillimeters")
func CGVirtualDisplayDescriptorSetSizeInMillimeters(_ descriptor: CGVirtualDisplayDescriptorRef, _ size: CGSize)

@_silgen_name("CGVirtualDisplayDescriptorSetQueueDepth")
func CGVirtualDisplayDescriptorSetQueueDepth(_ descriptor: CGVirtualDisplayDescriptorRef, _ depth: UInt32)

@_silgen_name("CGVirtualDisplaySettingsCreate")
func CGVirtualDisplaySettingsCreate() -> CGVirtualDisplaySettingsRef?

@_silgen_name("CGVirtualDisplaySettingsAddModeDescriptor")
func CGVirtualDisplaySettingsAddModeDescriptor(
    _ settings: CGVirtualDisplaySettingsRef,
    _ mode: CGVirtualDisplayModeDescriptorRef
)

@_silgen_name("CGVirtualDisplayModeDescriptorCreate")
func CGVirtualDisplayModeDescriptorCreate(
    _ width: UInt32,
    _ height: UInt32,
    _ refreshRate: Double
) -> CGVirtualDisplayModeDescriptorRef?

@_silgen_name("CGVirtualDisplaySetModes")
func CGVirtualDisplaySetModes(
    _ display: CGVirtualDisplayRef,
    _ settings: CGVirtualDisplaySettingsRef
) -> Bool

@_silgen_name("CGVirtualDisplayInvalidate")
func CGVirtualDisplayInvalidate(_ display: CGVirtualDisplayRef)
