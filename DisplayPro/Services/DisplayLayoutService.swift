import CoreGraphics
import Foundation
import OSLog

enum LayoutError: Error, LocalizedError {
    case configurationFailed(CGError)

    var errorDescription: String? {
        switch self {
        case .configurationFailed(let code): return "Layout configuration failed: \(code)"
        }
    }
}

final class DisplayLayoutService {
    private let logger = Logger.hardware

    func currentLayout() -> [CGDirectDisplayID: CGRect] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(16, &ids, &count)

        var layout: [CGDirectDisplayID: CGRect] = [:]
        for id in ids.prefix(Int(count)) {
            layout[id] = CGDisplayBounds(id)
        }
        return layout
    }

    func applyLayout(_ layout: [CGDirectDisplayID: CGPoint]) throws {
        var config: CGDisplayConfigRef?
        let beginError = CGBeginDisplayConfiguration(&config)
        guard beginError == .success, let cfg = config else {
            throw LayoutError.configurationFailed(beginError)
        }

        for (displayID, origin) in layout {
            CGConfigureDisplayOrigin(cfg, displayID, Int32(origin.x), Int32(origin.y))
        }

        let completeError = CGCompleteDisplayConfiguration(cfg, .forSession)
        guard completeError == .success else {
            CGCancelDisplayConfiguration(cfg)
            throw LayoutError.configurationFailed(completeError)
        }
        logger.info("Applied layout with \(layout.count) display(s)")
    }

    func setMirror(source: CGDirectDisplayID, mirroredTo target: CGDirectDisplayID) throws {
        var config: CGDisplayConfigRef?
        let beginError = CGBeginDisplayConfiguration(&config)
        guard beginError == .success, let cfg = config else {
            throw LayoutError.configurationFailed(beginError)
        }
        CGConfigureDisplayMirrorOfDisplay(cfg, source, target)
        let completeError = CGCompleteDisplayConfiguration(cfg, .forSession)
        guard completeError == .success else {
            CGCancelDisplayConfiguration(cfg)
            throw LayoutError.configurationFailed(completeError)
        }
    }

    func disableMirror(for displayID: CGDirectDisplayID) throws {
        var config: CGDisplayConfigRef?
        let beginError = CGBeginDisplayConfiguration(&config)
        guard beginError == .success, let cfg = config else {
            throw LayoutError.configurationFailed(beginError)
        }
        CGConfigureDisplayMirrorOfDisplay(cfg, displayID, kCGNullDirectDisplay)
        let completeError = CGCompleteDisplayConfiguration(cfg, .forSession)
        guard completeError == .success else {
            CGCancelDisplayConfiguration(cfg)
            throw LayoutError.configurationFailed(completeError)
        }
    }

    func setPrimary(displayID: CGDirectDisplayID, allDisplayIDs: [CGDirectDisplayID]) throws {
        var config: CGDisplayConfigRef?
        let beginError = CGBeginDisplayConfiguration(&config)
        guard beginError == .success, let cfg = config else {
            throw LayoutError.configurationFailed(beginError)
        }

        // Primary display origin is (0,0); adjust all others relative to it
        let primaryBounds = CGDisplayBounds(displayID)
        CGConfigureDisplayOrigin(cfg, displayID, 0, 0)
        for id in allDisplayIDs where id != displayID {
            let bounds = CGDisplayBounds(id)
            let newOrigin = CGPoint(
                x: bounds.origin.x - primaryBounds.origin.x,
                y: bounds.origin.y - primaryBounds.origin.y
            )
            CGConfigureDisplayOrigin(cfg, id, Int32(newOrigin.x), Int32(newOrigin.y))
        }

        let completeError = CGCompleteDisplayConfiguration(cfg, .forSession)
        guard completeError == .success else {
            CGCancelDisplayConfiguration(cfg)
            throw LayoutError.configurationFailed(completeError)
        }
    }
}
