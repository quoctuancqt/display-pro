import SwiftUI

struct LayoutCanvasView: View {
    @ObservedObject var viewModel: LayoutEditorViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid background
                Canvas { context, size in
                    let spacing: CGFloat = 20
                    var x: CGFloat = 0
                    while x <= size.width {
                        let path = Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        context.stroke(path, with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        let path = Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(path, with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)
                        y += spacing
                    }
                }

                ForEach(Array(viewModel.displayRects.keys), id: \.self) { displayID in
                    DisplayDragProxy(
                        displayID: displayID,
                        name: viewModel.displayNames[displayID] ?? "Display",
                        rect: viewModel.canvasRect(for: displayID, canvasSize: geometry.size),
                        onDrag: { delta in
                            let (scale, _) = viewModel.canvasTransform(canvasSize: geometry.size)
                            viewModel.moveDisplay(id: displayID, delta: delta, scale: scale)
                        }
                    )
                }
            }
            .clipped()
        }
    }
}
