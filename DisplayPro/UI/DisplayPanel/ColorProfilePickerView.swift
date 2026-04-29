import SwiftUI

struct ColorProfilePickerView: View {
    @ObservedObject var viewModel: DisplayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Color Profile")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: { viewModel.currentColorProfile },
                set: { newProfile in
                    guard let profile = newProfile else { return }
                    Task { await viewModel.setColorProfile(profile) }
                }
            )) {
                Text("None").tag(Optional<ColorProfile>.none)
                if !viewModel.colorProfiles.filter({ $0.isFactory }).isEmpty {
                    Divider()
                    ForEach(viewModel.colorProfiles.filter { $0.isFactory }) { profile in
                        Text(profile.name).tag(Optional(profile))
                    }
                }
                if !viewModel.colorProfiles.filter({ !$0.isFactory }).isEmpty {
                    Divider()
                    Section("Custom") {
                        ForEach(viewModel.colorProfiles.filter { !$0.isFactory }) { profile in
                            Text(profile.name).tag(Optional(profile))
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(viewModel.colorProfiles.isEmpty)
        }
    }
}
