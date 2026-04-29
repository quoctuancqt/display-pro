import SwiftUI

@main
struct DisplayProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra("DisplayPro", systemImage: "display") {
            MenuBarView()
                .environmentObject(appViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
