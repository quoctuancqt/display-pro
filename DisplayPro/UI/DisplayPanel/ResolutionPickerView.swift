import SwiftUI

struct ResolutionPickerView: View {
    @ObservedObject var viewModel: DisplayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Resolution")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("HiDPI", isOn: Binding(
                    get: { viewModel.showHiDPIModes },
                    set: { newVal in
                        viewModel.showHiDPIModes = newVal
                        Task {
                            viewModel.availableModes = ResolutionController().availableModes(
                                for: viewModel.id, includeHiDPI: newVal
                            )
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                Text("HiDPI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: Binding(
                get: { viewModel.currentMode },
                set: { newMode in
                    guard let mode = newMode else { return }
                    Task { await viewModel.setResolution(mode) }
                }
            )) {
                ForEach(viewModel.availableModes) { mode in
                    Text(mode.displayString)
                        .tag(Optional(mode))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(viewModel.isApplyingChange)
            .overlay(alignment: .trailing) {
                if viewModel.isApplyingChange {
                    ProgressView().scaleEffect(0.6).padding(.trailing, 24)
                }
            }
        }
    }
}
