import SwiftUI
import AppKit

@main
struct DisplayProApp: App {

    @StateObject private var manager = DisplayManager()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(manager: manager)
        } label: {
            Image(systemName: "display.2")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu content

struct MenuContentView: View {

    @ObservedObject var manager: DisplayManager
    @State private var showingDisableMainConfirmation: DisplayInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("Displays").font(.headline)
                Spacer()
                Button {
                    manager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }

            Divider()

            if manager.displays.isEmpty {
                Text("No displays detected.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else {
                ForEach(manager.displays) { display in
                    DisplayRow(
                        display: display,
                        onToggle: { newValue in
                            if display.isMain && !newValue {
                                showingDisableMainConfirmation = display
                            } else {
                                manager.setEnabled(newValue, for: display.id)
                            }
                        }
                    )
                }
            }

            Divider()

            Button {
                manager.reconnectAll()
            } label: {
                Label("Reconnect All", systemImage: "arrow.counterclockwise.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)

            if let err = manager.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            Divider()

            Button("Quit DisplayPro") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: 300)
        .confirmationDialog(
            "Disable the main display?",
            isPresented: Binding(
                get: { showingDisableMainConfirmation != nil },
                set: { if !$0 { showingDisableMainConfirmation = nil } }
            ),
            presenting: showingDisableMainConfirmation
        ) { display in
            Button("Disable “\(display.name)”", role: .destructive) {
                manager.setEnabled(false, for: display.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("macOS will reassign main to another active display. Use “Reconnect All” to recover if the screen goes blank.")
        }
    }
}

// MARK: - Row

struct DisplayRow: View {

    let display: DisplayInfo
    let onToggle: (Bool) -> Void

    private var iconName: String {
        if !display.isOnline { return "display.trianglebadge.exclamationmark" }
        return display.isActive ? "display" : "display.and.arrow.down"
    }

    private var subtitle: String {
        if !display.isOnline { return "Disconnected" }
        return "\(display.width) × \(display.height)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(display.isOnline ? Color.primary : Color.secondary)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(display.name)
                        .font(.body)
                        .foregroundStyle(display.isOnline ? Color.primary : Color.secondary)
                    if display.isMain {
                        Text("MAIN")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { display.isActive },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}
