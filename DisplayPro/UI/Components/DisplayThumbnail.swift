import SwiftUI

struct DisplayThumbnail: View {
    let displayID: CGDirectDisplayID
    var isSelected: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .overlay(
                Image(systemName: "display")
                    .foregroundStyle(.secondary)
            )
    }
}
