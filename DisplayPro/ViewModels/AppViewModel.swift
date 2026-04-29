import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var displays: [DisplayViewModel] = []
    @Published var isLoading: Bool = false

    private let observer: DisplayObserver
    private let brightnessController: BrightnessController
    private let resolutionController: ResolutionController
    private let colorProfileController: ColorProfileController
    private let ddcService: DDCServiceProtocol
    let layoutService: DisplayLayoutService
    let settingsStore: SettingsStore

    private var cancellables = Set<AnyCancellable>()

    init() {
        let ddc = DDCService.make()
        self.observer = DisplayObserver()
        self.brightnessController = BrightnessController(ddcService: ddc)
        self.resolutionController = ResolutionController()
        self.colorProfileController = ColorProfileController()
        self.ddcService = ddc
        self.layoutService = DisplayLayoutService()
        self.settingsStore = SettingsStore()

        // Subscribe to display reconfiguration events
        observer.displayChanged
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)

        // Also subscribe to NSScreen notifications
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)

        // Restore gamma on wake
        NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.brightnessController.restoreAllGamma()
            }
            .store(in: &cancellables)

        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let ids = activeDisplayIDs()

        // Preserve existing VMs if display is already known
        var newDisplays: [DisplayViewModel] = []
        for id in ids {
            if let existing = displays.first(where: { $0.id == id }) {
                await existing.loadState()
                newDisplays.append(existing)
            } else {
                let vm = DisplayViewModel(
                    displayID: id,
                    brightnessController: brightnessController,
                    resolutionController: resolutionController,
                    colorProfileController: colorProfileController,
                    ddcService: ddcService,
                    settingsStore: settingsStore
                )
                await vm.loadState()
                newDisplays.append(vm)
            }
        }
        displays = newDisplays
    }

    private func activeDisplayIDs() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(16, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }
}
