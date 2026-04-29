import CoreGraphics
import Foundation

struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    var name: String
    var hardware: DisplayHardware
    var currentMode: ResolutionMode?
    var brightness: Double
    var brightnessCapabilities: BrightnessCapabilities
    var colorProfile: ColorProfile?
    var position: CGPoint
    var isPrimary: Bool
    var inputSources: [InputSource]
    var currentInputSource: InputSource?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool { lhs.id == rhs.id }
}

struct InputSource: Identifiable, Hashable {
    let id: UUID
    let vcpValue: UInt16
    var label: String

    init(vcpValue: UInt16, label: String? = nil) {
        self.id = UUID()
        self.vcpValue = vcpValue
        self.label = label ?? InputSourceValue(rawValue: vcpValue)?.displayName ?? "Input \(vcpValue)"
    }
}
