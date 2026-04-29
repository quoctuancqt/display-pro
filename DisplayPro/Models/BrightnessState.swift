import Foundation

struct BrightnessState {
    // 0.0 = black, 1.0 = full hardware brightness, 2.0 = max XDR boost
    var value: Double
    let capabilities: BrightnessCapabilities

    var tier: BrightnessTier {
        if value < capabilities.hardwareMinimum { return .softwareDim }
        if value > 1.0 && capabilities.supportsXDRBoost { return .xdrBoost }
        return .hardware
    }

    var percentString: String {
        "\(Int(value * 100))%"
    }

    mutating func clamp() {
        value = min(max(value, 0.0), capabilities.maximumValue)
    }
}
