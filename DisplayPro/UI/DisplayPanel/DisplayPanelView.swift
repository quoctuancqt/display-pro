import SwiftUI

struct DisplayPanelView: View {
    @ObservedObject var viewModel: DisplayViewModel
    @State private var isExpanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 10) {
                if let caps = viewModel.brightnessCapabilities, caps.supportsHardwareBrightness {
                    BrightnessSliderView(viewModel: viewModel)
                }
                if !viewModel.availableModes.isEmpty {
                    Divider()
                    ResolutionPickerView(viewModel: viewModel)
                }
                Divider()
                ColorProfilePickerView(viewModel: viewModel)
                if !viewModel.inputSources.isEmpty {
                    Divider()
                    InputSourcePickerView(viewModel: viewModel)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)
        } label: {
            DisplayHeaderView(viewModel: viewModel)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 8)
    }
}

struct DisplayHeaderView: View {
    @ObservedObject var viewModel: DisplayViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.hardware?.isBuiltIn == true ? "laptopcomputer" : "display")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.name.isEmpty ? "Display" : viewModel.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let mode = viewModel.currentMode {
                    Text(mode.displayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if viewModel.hardware?.supportsXDR == true {
                Text("XDR")
                    .font(.caption2.bold())
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.yellow.opacity(0.15))
                    .foregroundStyle(.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            if viewModel.hardware?.isBuiltIn == false && viewModel.hardware?.hasDDC == true {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help("DDC/CI supported")
            }
        }
        .padding(.vertical, 4)
    }
}
