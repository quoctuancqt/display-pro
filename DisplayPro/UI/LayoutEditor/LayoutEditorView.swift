import SwiftUI

struct LayoutEditorView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var layoutVM: LayoutEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init() {
        // LayoutEditorViewModel is initialized with a placeholder; real init happens in onAppear
        // We use a workaround since EnvironmentObject isn't available in init
        _layoutVM = StateObject(wrappedValue: LayoutEditorViewModel(
            layoutService: DisplayLayoutService()
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            LayoutCanvasView(viewModel: layoutVM)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            footer
        }
        .frame(minWidth: 560, minHeight: 380)
        .onAppear {
            layoutVM.loadCurrentLayout(from: appViewModel.displays)
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Arrange Displays")
                .font(.headline)
            Spacer()
            Text("Drag displays to rearrange")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        Divider()
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button("Cancel") {
                    layoutVM.resetPending()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Apply") {
                    Task {
                        try? await layoutVM.applyPendingLayout()
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!layoutVM.isDirty)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}
