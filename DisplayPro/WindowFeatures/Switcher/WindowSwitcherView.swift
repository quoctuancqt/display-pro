import SwiftUI

struct WindowSwitcherView: View {
    @ObservedObject var model: SwitcherModel
    @ObservedObject var thumbnails: Thumbnails
    let onHover: (Int) -> Void
    let onClick: (Int) -> Void

    var body: some View {
        TileGrid(windows: model.windows, columns: model.columns) { index, window in
            WindowTile(
                window: window,
                image: thumbnails.images[window.id],
                thumbnailSize: model.thumbSize,
                isHighlighted: index == model.selection
            )
            .onHover { inside in if inside { onHover(index) } }
            .onTapGesture { onClick(index) }
        }
        .padding(12)
        .background(VisualEffectBackground(material: .hudWindow))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}
