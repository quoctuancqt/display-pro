import AppKit
import SwiftUI

/// Borderless, non-activating floating panel that never takes focus away
/// from the frontmost app.
final class OverlayPanel: NSPanel {

    init(level: NSWindow.Level = .popUpMenu, interactive: Bool) {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        self.level = level
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = interactive
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = !interactive
        acceptsMouseMovedEvents = interactive
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle, .transient]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Replaces the content and resizes the panel to fit it.
    @discardableResult
    func setContent<V: View>(_ view: V) -> CGSize {
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.intrinsicContentSize]
        contentView = hosting
        let size = hosting.fittingSize
        setContentSize(size)
        return size
    }
}

// MARK: - Shared SwiftUI pieces

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// One window: thumbnail (or app icon), title and a placement badge.
struct WindowTile: View {
    let window: WindowInfo
    let image: CGImage?
    let thumbnailSize: CGSize
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                        .opacity(window.placement == .minimized ? 0.6 : 1)
                } else if let icon = window.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .opacity(0.9)
                }
            }
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)

            HStack(spacing: 5) {
                if let icon = window.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                }
                Text(window.displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: thumbnailSize.width)

            if let badge = window.badge {
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted ? Color.accentColor.opacity(0.35) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isHighlighted ? Color.accentColor.opacity(0.8) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }
}

/// Lays tiles out in rows of `columns`.
struct TileGrid<Tile: View>: View {
    let windows: [WindowInfo]
    let columns: Int
    let tile: (Int, WindowInfo) -> Tile

    var body: some View {
        let cols = max(1, columns)
        let rows = stride(from: 0, to: windows.count, by: cols).map { start in
            Array(start..<min(start + cols, windows.count))
        }
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.first) { row in
                HStack(alignment: .top, spacing: 4) {
                    ForEach(row, id: \.self) { index in
                        tile(index, windows[index])
                    }
                }
            }
        }
    }
}

/// Picks a thumbnail size and column count so `count` tiles fit in `bounds`.
enum TileLayout {
    /// Extra space a tile takes beyond its thumbnail (padding, title, badge).
    static let chrome = CGSize(width: 16 + 4, height: 16 + 6 + 16 + 18 + 4)

    static func fit(count: Int, in bounds: CGSize, maxColumns: Int = .max,
                    preferredWidth: CGFloat, minWidth: CGFloat = 110) -> (thumb: CGSize, columns: Int) {
        let aspect: CGFloat = 0.625 // 16:10
        var width = preferredWidth
        while true {
            let thumb = CGSize(width: width, height: (width * aspect).rounded())
            let tileW = thumb.width + chrome.width
            let tileH = thumb.height + chrome.height
            let columns = max(1, min(count, maxColumns, Int(bounds.width / tileW)))
            let rows = Int((Double(count) / Double(columns)).rounded(.up))
            if CGFloat(rows) * tileH <= bounds.height || width <= minWidth {
                return (thumb, columns)
            }
            width -= 10
        }
    }
}
