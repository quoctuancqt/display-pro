import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var launchAtLogin: Bool = false
    @State private var menuBarIconStyle: MenuBarIconStyle = .display
    @State private var showHiDPIByDefault: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("DisplayPro Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            Form {
                Section("General") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newVal in
                            appViewModel.settingsStore.launchAtLogin = newVal
                            if newVal {
                                try? SMAppService.mainApp.register()
                            } else {
                                try? SMAppService.mainApp.unregister()
                            }
                        }
                }

                Section("Display") {
                    Toggle("Show HiDPI modes by default", isOn: $showHiDPIByDefault)
                        .onChange(of: showHiDPIByDefault) { newVal in
                            appViewModel.settingsStore.showHiDPIByDefault = newVal
                        }

                    Picker("Menu Bar Icon", selection: $menuBarIconStyle) {
                        ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                            Label(style.rawValue.capitalized, systemImage: style.systemImage)
                                .tag(style)
                        }
                    }
                    .onChange(of: menuBarIconStyle) { newVal in
                        appViewModel.settingsStore.menuBarIconStyle = newVal
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 360, height: 320)
        .onAppear {
            launchAtLogin = appViewModel.settingsStore.launchAtLogin
            menuBarIconStyle = appViewModel.settingsStore.menuBarIconStyle
            showHiDPIByDefault = appViewModel.settingsStore.showHiDPIByDefault
        }
    }
}
