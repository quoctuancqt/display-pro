import Foundation

final class SettingsStore {
    private let defaults = UserDefaults(suiteName: "com.displaypro.app")!

    // MARK: - Per-display preferences (keyed by display UUID string)

    func preferredResolution(for displayUUID: String) -> [String: Any]? {
        defaults.dictionary(forKey: "resolution_\(displayUUID)")
    }

    func setPreferredResolution(width: Int, height: Int, refreshRate: Double, isHiDPI: Bool, for displayUUID: String) {
        defaults.set([
            "width": width,
            "height": height,
            "refreshRate": refreshRate,
            "isHiDPI": isHiDPI
        ], forKey: "resolution_\(displayUUID)")
    }

    func preferredBrightness(for displayUUID: String) -> Double? {
        let key = "brightness_\(displayUUID)"
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.double(forKey: key)
    }

    func setPreferredBrightness(_ value: Double, for displayUUID: String) {
        defaults.set(value, forKey: "brightness_\(displayUUID)")
    }

    func preferredColorProfileURL(for displayUUID: String) -> URL? {
        guard let path = defaults.string(forKey: "colorProfile_\(displayUUID)") else { return nil }
        return URL(fileURLWithPath: path)
    }

    func setPreferredColorProfileURL(_ url: URL, for displayUUID: String) {
        defaults.set(url.path, forKey: "colorProfile_\(displayUUID)")
    }

    // MARK: - Input source labels

    func inputSourceLabel(monitorModel: UInt32, vcpValue: UInt16) -> String? {
        defaults.string(forKey: "inputLabel_\(monitorModel)_\(vcpValue)")
    }

    func setInputSourceLabel(_ label: String, monitorModel: UInt32, vcpValue: UInt16) {
        defaults.set(label, forKey: "inputLabel_\(monitorModel)_\(vcpValue)")
    }

    // MARK: - App preferences

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    var menuBarIconStyle: MenuBarIconStyle {
        get { MenuBarIconStyle(rawValue: defaults.string(forKey: "menuBarIconStyle") ?? "") ?? .display }
        set { defaults.set(newValue.rawValue, forKey: "menuBarIconStyle") }
    }

    var showHiDPIByDefault: Bool {
        get { defaults.object(forKey: "showHiDPIByDefault") == nil ? true : defaults.bool(forKey: "showHiDPIByDefault") }
        set { defaults.set(newValue, forKey: "showHiDPIByDefault") }
    }
}

enum MenuBarIconStyle: String, CaseIterable {
    case display = "display"
    case text = "text"
    case minimal = "minimal"

    var systemImage: String {
        switch self {
        case .display: return "display"
        case .text: return "textformat"
        case .minimal: return "circle.fill"
        }
    }
}
