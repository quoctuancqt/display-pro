import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingLayoutEditor = false
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if appViewModel.isLoading && appViewModel.displays.isEmpty {
                loadingView
            } else if appViewModel.displays.isEmpty {
                emptyView
            } else {
                displayList
            }

            Divider()
            footerView
        }
        .frame(width: 320)
        .sheet(isPresented: $showingLayoutEditor) {
            LayoutEditorView()
                .environmentObject(appViewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(appViewModel)
        }
    }

    @ViewBuilder
    private var displayList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(appViewModel.displays) { displayVM in
                    DisplayPanelView(viewModel: displayVM)
                    if displayVM.id != appViewModel.displays.last?.id {
                        Divider()
                            .padding(.horizontal, 8)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .scrollIndicators(.never)
        .frame(maxHeight: 480)
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading displays…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 60)
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No displays found")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 60)
    }

    private var footerView: some View {
        HStack {
            Button {
                showingLayoutEditor = true
            } label: {
                Label("Arrange", systemImage: "square.grid.2x2")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(appViewModel.displays.count < 2)

            Spacer()

            Button {
                Task { await appViewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Refresh displays")

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Quit DisplayPro")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
