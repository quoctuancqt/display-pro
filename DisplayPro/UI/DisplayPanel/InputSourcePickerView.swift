import SwiftUI

struct InputSourcePickerView: View {
    @ObservedObject var viewModel: DisplayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Input Source")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: { viewModel.currentInputSource },
                set: { newSource in
                    guard let source = newSource else { return }
                    Task { await viewModel.setInputSource(source) }
                }
            )) {
                Text("Unknown").tag(Optional<InputSource>.none)
                ForEach(viewModel.inputSources) { source in
                    Text(source.label).tag(Optional(source))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(viewModel.isApplyingChange)
        }
    }
}
