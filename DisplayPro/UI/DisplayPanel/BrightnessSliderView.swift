import SwiftUI

struct BrightnessSliderView: View {
    @ObservedObject var viewModel: DisplayViewModel

    private var sliderMax: Double {
        viewModel.brightnessCapabilities?.supportsXDRBoost == true ? 2.0 : 1.0
    }

    private var brightnessLabel: String {
        let pct = Int(viewModel.brightness * 100)
        if pct > 100 { return "\(pct)% ✦" }  // XDR boost indicator
        return "\(pct)%"
    }

    private var tierColor: Color {
        switch viewModel.brightnessCapabilities.map({ BrightnessTierHelper.tier(value: viewModel.brightness, caps: $0) }) {
        case .some(.softwareDim): return .gray
        case .some(.xdrBoost): return .yellow
        default: return .primary
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "sun.min")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track background
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)

                        // XDR region marker
                        if sliderMax > 1.0 {
                            let xdrStart = geo.size.width / CGFloat(sliderMax)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: geo.size.width - xdrStart, height: 4)
                                .offset(x: xdrStart)
                        }

                        // 100% tick
                        if sliderMax > 1.0 {
                            let tickX = geo.size.width / CGFloat(sliderMax)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: 1, height: 8)
                                .offset(x: tickX - 0.5, y: -2)
                        }
                    }
                }
                .frame(height: 8)
                .overlay(
                    Slider(
                        value: Binding(
                            get: { viewModel.brightness },
                            set: { viewModel.setBrightness($0) }
                        ),
                        in: 0.0...sliderMax
                    )
                    .labelsHidden()
                    .tint(tierColor)
                )

                Image(systemName: sliderMax > 1.0 ? "sun.max.trianglebadge.exclamationmark" : "sun.max")
                    .font(.caption)
                    .foregroundStyle(sliderMax > 1.0 ? .yellow : .secondary)

                Text(brightnessLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(viewModel.brightness > 1.0 ? .yellow : .secondary)
                    .frame(width: 44, alignment: .trailing)
            }

            if viewModel.brightnessCapabilities?.supportsXDRBoost == true {
                Text("XDR boost active above 100%")
                    .font(.caption2)
                    .foregroundStyle(.yellow.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .opacity(viewModel.brightness > 1.0 ? 1 : 0)
            }
        }
    }
}

// Helper to avoid circular dependency with BrightnessCapabilities
private enum BrightnessTierHelper {
    static func tier(value: Double, caps: BrightnessCapabilities) -> BrightnessTier {
        if value < caps.hardwareMinimum { return .softwareDim }
        if value > 1.0 && caps.supportsXDRBoost { return .xdrBoost }
        return .hardware
    }
}
