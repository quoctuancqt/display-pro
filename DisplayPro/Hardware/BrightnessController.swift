import CoreGraphics
import Foundation
import OSLog

struct BrightnessCapabilities: Equatable {
    let supportsHardwareBrightness: Bool
    let supportsXDRBoost: Bool
    let hardwareMinimum: Double
    let isDDCExternal: Bool
    let isBuiltIn: Bool

    var maximumValue: Double { supportsXDRBoost ? 2.0 : 1.0 }
}

enum BrightnessTier {
    case softwareDim   // below hardware minimum — gamma table
    case hardware      // hardware brightness range
    case xdrBoost      // above 1.0 — XDR/HDR headroom
}

final class BrightnessController {
    private let logger = Logger.hardware
    private let ddcService: DDCServiceProtocol
    private var savedGammaTables: [CGDirectDisplayID: GammaTable] = [:]

    init(ddcService: DDCServiceProtocol) {
        self.ddcService = ddcService
    }

    func capabilities(for displayID: CGDirectDisplayID) -> BrightnessCapabilities {
        let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
        let canChange = DisplayServicesCanChangeBrightness(displayID)
        var maxPotential: Float = 0
        _ = DisplayServicesGetMaximumPotentialBrightness(displayID, &maxPotential)

        let isDDC = !isBuiltIn && ddcService.isSupported(displayID: displayID)

        return BrightnessCapabilities(
            supportsHardwareBrightness: canChange || isDDC,
            supportsXDRBoost: maxPotential > 1.0 && canChange,
            hardwareMinimum: 0.005,
            isDDCExternal: isDDC,
            isBuiltIn: isBuiltIn
        )
    }

    // value: 0.0 (black) ... 1.0 (full hardware) ... 2.0 (max XDR boost)
    func setBrightness(_ value: Double, for displayID: CGDirectDisplayID) async throws {
        let caps = capabilities(for: displayID)
        let clamped = min(max(value, 0.0), caps.maximumValue)
        let tier = tier(for: clamped, caps: caps)

        switch tier {
        case .softwareDim:
            // Apply gamma dim while also setting hardware to minimum
            applyGammaDim(level: clamped / caps.hardwareMinimum, displayID: displayID)
            if caps.isDDCExternal {
                let ddcMin = UInt16(caps.hardwareMinimum * 100)
                try? await ddcService.writeValue(displayID: displayID, code: .brightness, value: ddcMin)
            } else if caps.supportsHardwareBrightness {
                _ = DisplayServicesSetBrightness(displayID, Float(caps.hardwareMinimum))
            }

        case .hardware:
            restoreGamma(for: displayID)
            if caps.isDDCExternal {
                let ddcValue = UInt16(clamped * 100)
                try await ddcService.writeValue(displayID: displayID, code: .brightness, value: ddcValue)
            } else {
                let result = DisplayServicesSetBrightness(displayID, Float(clamped))
                if result != 0 {
                    CoreDisplay_Display_SetUserBrightness(displayID, clamped)
                }
            }

        case .xdrBoost:
            restoreGamma(for: displayID)
            // Map 1.0–2.0 to 1.0–1.6 for DisplayServices XDR range
            let xdrValue = 1.0 + (clamped - 1.0) * 0.6
            _ = DisplayServicesSetMaximumPotentialBrightness(displayID, Float(xdrValue))
            _ = DisplayServicesSetBrightness(displayID, Float(xdrValue))
        }
    }

    func getBrightness(for displayID: CGDirectDisplayID) -> Double {
        let caps = capabilities(for: displayID)

        if caps.isDDCExternal {
            // DDC read is async; return cached/default
            return 0.5
        }

        var brightness: Float = 0
        if DisplayServicesGetBrightness(displayID, &brightness) == 0 {
            let value = Double(brightness)
            // Map XDR range back to 1.0–2.0
            if value > 1.0 {
                return 1.0 + (value - 1.0) / 0.6
            }
            return value
        }
        return Double(CoreDisplay_Display_GetUserBrightness(displayID))
    }

    // MARK: - Gamma

    private func applyGammaDim(level: Double, displayID: CGDirectDisplayID) {
        let capacity = 256
        if savedGammaTables[displayID] == nil {
            var red = [Float](repeating: 0, count: capacity)
            var green = [Float](repeating: 0, count: capacity)
            var blue = [Float](repeating: 0, count: capacity)
            var count: UInt32 = 0
            CGGetDisplayTransferByTable(displayID, UInt32(capacity), &red, &green, &blue, &count)
            savedGammaTables[displayID] = GammaTable(red: red, green: green, blue: blue)
        }

        let scale = Float(max(0.0, min(level, 1.0)))
        var red = [Float](repeating: 0, count: capacity)
        var green = [Float](repeating: 0, count: capacity)
        var blue = [Float](repeating: 0, count: capacity)
        for i in 0..<capacity {
            let base = Float(i) / Float(capacity - 1)
            red[i] = base * scale
            green[i] = base * scale
            blue[i] = base * scale
        }
        CGSetDisplayTransferByTable(displayID, UInt32(capacity), &red, &green, &blue)
    }

    func restoreGamma(for displayID: CGDirectDisplayID) {
        guard let saved = savedGammaTables[displayID] else { return }
        var red = saved.red
        var green = saved.green
        var blue = saved.blue
        CGSetDisplayTransferByTable(displayID, UInt32(red.count), &red, &green, &blue)
        savedGammaTables.removeValue(forKey: displayID)
    }

    func restoreAllGamma() {
        for displayID in savedGammaTables.keys {
            restoreGamma(for: displayID)
        }
    }

    // MARK: - Helpers

    private func tier(for value: Double, caps: BrightnessCapabilities) -> BrightnessTier {
        if value < caps.hardwareMinimum { return .softwareDim }
        if value > 1.0 && caps.supportsXDRBoost { return .xdrBoost }
        return .hardware
    }
}

private struct GammaTable {
    let red: [Float]
    let green: [Float]
    let blue: [Float]
}
