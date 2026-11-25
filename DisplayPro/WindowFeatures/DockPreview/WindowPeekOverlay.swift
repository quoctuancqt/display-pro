import AppKit
import SwiftUI

/// Shows a window "in place": a full-resolution capture drawn at the window's
/// real position over a dimmed screen. Z-order and focus are left alone, and
/// the overlay ignores the mouse.
@MainActor
final class WindowPeekOverlay {

    private var panel: OverlayPanel?

    var isVisible: Bool { panel?.isVisible == true }

    func show(_ window: WindowInfo, image: CGImage) {
        let frame = ScreenGeometry.cocoa(fromCG: window.frame)
        guard let screen = ScreenGeometry.screen(for: frame) ?? NSScreen.main else { return }

        // Just below the Dock preview panel, above everything else.
        let panel = self.panel ?? OverlayPanel(level: NSWindow.Level(NSWindow.Level.popUpMenu.rawValue - 1),
                                               interactive: false)
        self.panel = panel

        let content = ZStack(alignment: .topLeading) {
            Color.black.opacity(0.35)
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.high)
                .frame(width: frame.width, height: frame.height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
                .offset(x: frame.minX - screen.frame.minX, y: screen.frame.maxY - frame.maxY)
        }
        .frame(width: screen.frame.width, height: screen.frame.height, alignment: .topLeading)

        panel.setContent(content)
        panel.setFrame(screen.frame, display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }
}
