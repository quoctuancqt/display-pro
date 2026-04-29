import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class LayoutEditorViewModel: ObservableObject {
    @Published var displayRects: [CGDirectDisplayID: CGRect] = [:]
    @Published var displayNames: [CGDirectDisplayID: String] = [:]
    @Published var pendingOrigins: [CGDirectDisplayID: CGPoint] = [:]
    @Published var isDirty: Bool = false

    let layoutService: DisplayLayoutService

    init(layoutService: DisplayLayoutService) {
        self.layoutService = layoutService
    }

    func loadCurrentLayout(from displays: [DisplayViewModel]) {
        let layout = layoutService.currentLayout()
        displayRects = layout
        for vm in displays {
            displayNames[vm.id] = vm.name
        }
        pendingOrigins.removeAll()
        isDirty = false
    }

    func moveDisplay(id: CGDirectDisplayID, delta: CGSize, scale: CGFloat) {
        let current = pendingOrigins[id] ?? displayRects[id]?.origin ?? .zero
        pendingOrigins[id] = CGPoint(
            x: current.x + delta.width / scale,
            y: current.y + delta.height / scale
        )
        isDirty = true
    }

    func applyPendingLayout() async throws {
        var layoutToApply: [CGDirectDisplayID: CGPoint] = [:]
        for (id, rect) in displayRects {
            layoutToApply[id] = pendingOrigins[id] ?? rect.origin
        }
        try layoutService.applyLayout(layoutToApply)
        pendingOrigins.removeAll()
        isDirty = false

        // Reload after applying
        let updatedLayout = layoutService.currentLayout()
        displayRects = updatedLayout
    }

    func resetPending() {
        pendingOrigins.removeAll()
        isDirty = false
    }

    // Convert global display coordinate space to canvas coordinate space
    func canvasTransform(canvasSize: CGSize) -> (scale: CGFloat, offset: CGPoint) {
        guard !displayRects.isEmpty else { return (1, .zero) }

        let allRects = displayRects.values.map { rect -> CGRect in
            if let pending = pendingOrigins[displayRects.first(where: { $0.value == rect })?.key ?? 0] {
                return CGRect(origin: pending, size: rect.size)
            }
            return rect
        }

        let minX = allRects.map { $0.minX }.min() ?? 0
        let minY = allRects.map { $0.minY }.min() ?? 0
        let maxX = allRects.map { $0.maxX }.max() ?? 1
        let maxY = allRects.map { $0.maxY }.max() ?? 1
        let totalWidth = maxX - minX
        let totalHeight = maxY - minY

        let padding: CGFloat = 32
        let scaleX = (canvasSize.width - padding * 2) / totalWidth
        let scaleY = (canvasSize.height - padding * 2) / totalHeight
        let scale = min(scaleX, scaleY, 0.5)  // cap at 0.5 to avoid oversized tiles

        let offsetX = (canvasSize.width - totalWidth * scale) / 2 - minX * scale
        let offsetY = (canvasSize.height - totalHeight * scale) / 2 - minY * scale

        return (scale, CGPoint(x: offsetX, y: offsetY))
    }

    func canvasRect(for displayID: CGDirectDisplayID, canvasSize: CGSize) -> CGRect {
        guard let globalRect = displayRects[displayID] else { return .zero }
        let origin = pendingOrigins[displayID] ?? globalRect.origin
        let (scale, offset) = canvasTransform(canvasSize: canvasSize)

        return CGRect(
            x: origin.x * scale + offset.x,
            y: origin.y * scale + offset.y,
            width: globalRect.width * scale,
            height: globalRect.height * scale
        )
    }
}
