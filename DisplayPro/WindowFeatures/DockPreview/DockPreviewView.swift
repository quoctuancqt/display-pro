import SwiftUI

@MainActor
final class DockPreviewModel: ObservableObject {
    @Published var appName = ""
    @Published var appIcon: NSImage?
    @Published var windows: [WindowInfo] = []
    @Published var hovered: CGWindowID?
    @Published var thumbSize = CGSize(width: 200, height: 125)
    @Published var columns = 1
}

struct DockPreviewView: View {
    @ObservedObject var model: DockPreviewModel
    @ObservedObject var thumbnails: Thumbnails
    let onHover: (WindowInfo?) -> Void
    let onClick: (WindowInfo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let icon = model.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                Text(model.appName)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
                Text(model.windows.count == 1 ? "1 window" : "\(model.windows.count) windows")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)

            TileGrid(windows: model.windows, columns: model.columns) { _, window in
                WindowTile(
                    window: window,
                    image: thumbnails.images[window.id],
                    thumbnailSize: model.thumbSize,
                    isHighlighted: model.hovered == window.id
                )
                .onHover { inside in
                    if inside {
                        onHover(window)
                    } else if model.hovered == window.id {
                        onHover(nil)
                    }
                }
                .onTapGesture { onClick(window) }
            }
        }
        .padding(10)
        .background(VisualEffectBackground(material: .hudWindow))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}
