import SwiftUI

/// Menu-bar section with the Dock Preview and ⌘Tab toggles, plus permission
/// prompts when something is missing. Used by both app entry points.
struct WindowFeaturesSection: View {
    @ObservedObject private var features = WindowFeatures.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureToggle(
                isOn: $features.dockPreviewEnabled,
                icon: "dock.rectangle",
                title: "Dock Preview",
                subtitle: subtitle(enabled: features.dockPreviewEnabled,
                                   running: features.dockPreviewRunning,
                                   on: "Hover Dock icons to see windows",
                                   off: "Off"),
                help: "Hover over the Dock to see each window. Pause on a preview to peek at the window in place."
            )

            featureToggle(
                isOn: $features.windowSwitcherEnabled,
                icon: "rectangle.on.rectangle",
                title: "⌘Tab Window Switcher",
                subtitle: subtitle(enabled: features.windowSwitcherEnabled,
                                   running: features.windowSwitcherRunning,
                                   on: "Switch between individual windows",
                                   off: "Using the system switcher"),
                help: "⌘Tab through every window, including those on other Spaces and displays."
            )

            if needsPermissions {
                permissionsRow
            }
        }
    }

    private var needsPermissions: Bool {
        (features.dockPreviewEnabled || features.windowSwitcherEnabled)
            && (!features.hasAccessibility || !features.hasScreenRecording)
    }

    private func subtitle(enabled: Bool, running: Bool, on: String, off: String) -> String {
        guard enabled else { return off }
        if running { return on }
        return features.hasAccessibility ? "Could not start" : "Needs Accessibility access"
    }

    private func featureToggle(isOn: Binding<Bool>, icon: String, title: String,
                               subtitle: String, help: String) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isOn.wrappedValue ? Color.accentColor : Color.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .help(help)
    }

    private var permissionsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !features.hasAccessibility {
                permissionButton("Grant Accessibility Access…", systemImage: "hand.raised") {
                    features.requestAccessibility()
                }
            }
            if !features.hasScreenRecording {
                permissionButton("Grant Screen Recording for Thumbnails…", systemImage: "rectangle.dashed.badge.record") {
                    features.requestScreenRecording()
                }
                Text("Without it, previews show app icons. You may need to relaunch DisplayPro after granting it.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 28)
    }

    private func permissionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption)
        }
        .buttonStyle(.borderless)
    }
}
