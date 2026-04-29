import SwiftUI

struct DisplayDragProxy: View {
    let displayID: CGDirectDisplayID
    let name: String
    let rect: CGRect
    let onDrag: (CGSize) -> Void

    @State private var currentOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isDragging ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isDragging ? Color.accentColor : Color.secondary.opacity(0.4),
                        lineWidth: isDragging ? 2 : 1
                    )
            )
            .overlay(
                VStack(spacing: 3) {
                    Image(systemName: "display")
                        .font(.system(size: min(rect.height * 0.3, 24)))
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.caption2)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                    Text("\(Int(rect.width / 0.15)) × \(Int(rect.height / 0.15))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            )
            .frame(width: rect.width, height: rect.height)
            .position(
                x: rect.midX + currentOffset.width,
                y: rect.midY + currentOffset.height
            )
            .shadow(color: isDragging ? .black.opacity(0.2) : .clear, radius: 4, y: 2)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        isDragging = true
                        currentOffset = value.translation
                    }
                    .onEnded { value in
                        isDragging = false
                        onDrag(value.translation)
                        currentOffset = .zero
                    }
            )
            .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}
