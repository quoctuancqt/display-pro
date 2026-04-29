import CoreGraphics
import Foundation

struct ResolutionMode: Identifiable, Hashable {
    let id: UUID
    let width: Int
    let height: Int
    let refreshRate: Double
    let isHiDPI: Bool
    let pixelWidth: Int
    let pixelHeight: Int
    let cgMode: CGDisplayMode

    init(cgMode: CGDisplayMode) {
        self.id = UUID()
        self.width = cgMode.width
        self.height = cgMode.height
        self.refreshRate = cgMode.refreshRate
        self.pixelWidth = cgMode.pixelWidth
        self.pixelHeight = cgMode.pixelHeight
        // A mode is HiDPI when pixel dimensions are larger than logical dimensions
        self.isHiDPI = cgMode.pixelWidth > cgMode.width || cgMode.pixelHeight > cgMode.height
        self.cgMode = cgMode
    }

    var displayString: String {
        let hiDPITag = isHiDPI ? " (HiDPI)" : ""
        let hz = refreshRate > 0 ? " @ \(Int(refreshRate))Hz" : ""
        return "\(width) × \(height)\(hiDPITag)\(hz)"
    }

    // Hashable/Equatable ignoring UUID (same logical mode = same hash)
    func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(Int(refreshRate))
        hasher.combine(isHiDPI)
    }

    static func == (lhs: ResolutionMode, rhs: ResolutionMode) -> Bool {
        lhs.width == rhs.width
            && lhs.height == rhs.height
            && Int(lhs.refreshRate) == Int(rhs.refreshRate)
            && lhs.isHiDPI == rhs.isHiDPI
    }
}
