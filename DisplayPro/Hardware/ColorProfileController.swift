import CoreGraphics
import Foundation
import ColorSync
import OSLog

final class ColorProfileController {
    private let logger = Logger.hardware

    func availableProfiles() -> [ColorProfile] {
        var profiles: [ColorProfile] = []

        let searchPaths: [String] = [
            "/Library/ColorSync/Profiles",
            NSString("~/Library/ColorSync/Profiles").expandingTildeInPath,
            "/System/Library/ColorSync/Profiles"
        ]

        for path in searchPaths {
            let url = URL(fileURLWithPath: path)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: .skipsHiddenFiles
            ) else { continue }

            let iccFiles = contents.filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "icc" || ext == "icm"
            }
            for fileURL in iccFiles {
                if let profile = ColorProfile(url: fileURL) {
                    profiles.append(profile)
                }
            }
        }

        return profiles.sorted { $0.name < $1.name }
    }

    func currentProfile(for displayID: CGDirectDisplayID) -> ColorProfile? {
        let colorSpace = CGDisplayCopyColorSpace(displayID)
        guard let iccData = colorSpace.copyICCData() as Data? else { return nil }

        // Match against known profiles by ICC data
        for profile in availableProfiles() {
            if let profileData = try? Data(contentsOf: profile.url),
               profileData == iccData {
                return profile
            }
        }

        // Return synthetic profile named after color space
        let name = colorSpace.name.map { $0 as String } ?? "Current Profile"
        return ColorProfile(name: name, url: URL(fileURLWithPath: "/tmp/current"), isFactory: true)
    }

    func setProfile(_ profile: ColorProfile, for displayID: CGDirectDisplayID) throws {
        // ColorSyncDeviceSetCustomProfiles(deviceClass, deviceUUID, profileInfo)
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return }

        // ColorSync constants are Unmanaged<CFString>? — unwrap safely
        guard let urlKey = kColorSyncDeviceProfileURL?.takeUnretainedValue() as CFString?,
              let defaultIDKey = kColorSyncDeviceDefaultProfileID?.takeUnretainedValue() as CFString?,
              let customKey = kColorSyncCustomProfiles?.takeUnretainedValue() as CFString?,
              let deviceClass = kColorSyncDisplayDeviceClass?.takeUnretainedValue() as CFString? else {
            logger.error("ColorSync constants unavailable")
            return
        }

        // profileInfo structure:
        // { kColorSyncCustomProfiles: { kColorSyncDeviceDefaultProfileID: { kColorSyncDeviceProfileURL: cfurl } } }
        let innerProfile = [urlKey: profile.url as CFURL] as CFDictionary
        let customProfiles = [defaultIDKey: innerProfile] as CFDictionary
        let profileInfo = [customKey: customProfiles] as CFDictionary

        if !ColorSyncDeviceSetCustomProfiles(deviceClass, cfUUID, profileInfo) {
            logger.error("Failed to set color profile \(profile.name) for display \(displayID)")
        } else {
            logger.info("Set profile \(profile.name) for display \(displayID)")
        }
    }
}
