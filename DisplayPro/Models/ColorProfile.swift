import Foundation
import ColorSync

struct ColorProfile: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    let isFactory: Bool
    let colorSpaceDescription: String

    init(name: String, url: URL, isFactory: Bool) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.isFactory = isFactory
        self.colorSpaceDescription = ColorProfile.colorSpaceDescription(for: url)
    }

    init?(url: URL) {
        guard let profile = ColorSyncProfileCreateWithURL(url as CFURL, nil)?.takeRetainedValue() else {
            return nil
        }
        let name = (ColorSyncProfileCopyDescriptionString(profile)?.takeRetainedValue() as String?) ?? url.deletingPathExtension().lastPathComponent
        let systemPaths = ["/System/Library/ColorSync/Profiles", "/Library/ColorSync/Profiles"]
        let isFactory = systemPaths.contains { url.path.hasPrefix($0) }

        self.id = UUID()
        self.name = name
        self.url = url
        self.isFactory = isFactory
        self.colorSpaceDescription = ColorProfile.colorSpaceDescription(for: url)
    }

    private static func colorSpaceDescription(for url: URL) -> String {
        // Read color space signature from raw ICC profile data (bytes 16-19)
        guard let data = try? Data(contentsOf: url), data.count >= 20 else { return "Unknown" }
        let sigBytes = data[16..<20]
        let sig = String(bytes: sigBytes, encoding: .ascii)?.trimmingCharacters(in: CharacterSet.whitespaces) ?? ""
        switch sig {
        case "RGB": return "RGB"
        case "GRAY": return "Grayscale"
        case "CMYK": return "CMYK"
        default: return sig.isEmpty ? "Unknown" : sig
        }
    }
}
