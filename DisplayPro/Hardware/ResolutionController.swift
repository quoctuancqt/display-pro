import CoreGraphics
import Foundation
import OSLog

enum ResolutionError: Error, LocalizedError {
    case configurationFailed(CGError)
    case modeNotAvailable

    var errorDescription: String? {
        switch self {
        case .configurationFailed(let code): return "Display configuration failed: \(code)"
        case .modeNotAvailable: return "Requested resolution mode is not available"
        }
    }
}

final class ResolutionController {
    private let logger = Logger.hardware

    func availableModes(for displayID: CGDirectDisplayID, includeHiDPI: Bool = true) -> [ResolutionMode] {
        let options: [CFString: Any] = includeHiDPI
            ? [kCGDisplayShowDuplicateLowResolutionModes: true]
            : [:]
        guard let rawModes = CGDisplayCopyAllDisplayModes(displayID, options as CFDictionary) as? [CGDisplayMode] else {
            return []
        }

        return rawModes
            .compactMap { cgMode -> ResolutionMode? in
                guard cgMode.isUsableForDesktopGUI() else { return nil }
                return ResolutionMode(cgMode: cgMode)
            }
            .sorted { lhs, rhs in
                if lhs.width != rhs.width { return lhs.width > rhs.width }
                if lhs.height != rhs.height { return lhs.height > rhs.height }
                if lhs.refreshRate != rhs.refreshRate { return lhs.refreshRate > rhs.refreshRate }
                return lhs.isHiDPI && !rhs.isHiDPI
            }
    }

    func currentMode(for displayID: CGDirectDisplayID) -> ResolutionMode? {
        guard let cgMode = CGDisplayCopyDisplayMode(displayID) else { return nil }
        return ResolutionMode(cgMode: cgMode)
    }

    func applyMode(_ mode: ResolutionMode, to displayID: CGDirectDisplayID) throws {
        var config: CGDisplayConfigRef?
        let beginError = CGBeginDisplayConfiguration(&config)
        guard beginError == .success, let cfg = config else {
            throw ResolutionError.configurationFailed(beginError)
        }

        let configError = CGConfigureDisplayWithDisplayMode(cfg, displayID, mode.cgMode, nil)
        guard configError == .success else {
            CGCancelDisplayConfiguration(cfg)
            throw ResolutionError.configurationFailed(configError)
        }

        let completeError = CGCompleteDisplayConfiguration(cfg, .forSession)
        guard completeError == .success else {
            throw ResolutionError.configurationFailed(completeError)
        }
        logger.info("Applied mode \(mode.displayString) to display \(displayID)")
    }
}
