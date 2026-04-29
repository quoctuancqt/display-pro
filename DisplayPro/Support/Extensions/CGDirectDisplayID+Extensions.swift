import AppKit
import CoreGraphics

extension CGDirectDisplayID {
    var uuidString: String? {
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(self)?.takeUnretainedValue() else { return nil }
        return CFUUIDCreateString(nil, cfUUID) as String?
    }

    var isBuiltIn: Bool { CGDisplayIsBuiltin(self) != 0 }
    var isOnline: Bool { CGDisplayIsOnline(self) != 0 }
    var isMain: Bool { CGDisplayIsMain(self) != 0 }
    var isMirrored: Bool { CGDisplayIsInMirrorSet(self) != 0 }

    var localizedName: String {
        if let screen = NSScreen.screens.first(where: { $0.displayID == self }) {
            return screen.localizedName
        }
        return isBuiltIn ? "Built-in Display" : "External Display \(self)"
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
