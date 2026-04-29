import Combine
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class DisplayViewModel: ObservableObject, Identifiable {
    let id: CGDirectDisplayID

    @Published var name: String = ""
    @Published var brightness: Double = 1.0
    @Published var brightnessCapabilities: BrightnessCapabilities?
    @Published var availableModes: [ResolutionMode] = []
    @Published var currentMode: ResolutionMode?
    @Published var showHiDPIModes: Bool = true
    @Published var colorProfiles: [ColorProfile] = []
    @Published var currentColorProfile: ColorProfile?
    @Published var inputSources: [InputSource] = []
    @Published var currentInputSource: InputSource?
    @Published var isApplyingChange: Bool = false
    @Published var hardware: DisplayHardware?

    private let brightnessController: BrightnessController
    private let resolutionController: ResolutionController
    private let colorProfileController: ColorProfileController
    private let ddcService: DDCServiceProtocol
    private let settingsStore: SettingsStore

    private var brightnessDebounceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    var displayUUID: String {
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeUnretainedValue() else { return "\(id)" }
        return CFUUIDCreateString(nil, cfUUID) as String? ?? "\(id)"
    }

    init(
        displayID: CGDirectDisplayID,
        brightnessController: BrightnessController,
        resolutionController: ResolutionController,
        colorProfileController: ColorProfileController,
        ddcService: DDCServiceProtocol,
        settingsStore: SettingsStore
    ) {
        self.id = displayID
        self.brightnessController = brightnessController
        self.resolutionController = resolutionController
        self.colorProfileController = colorProfileController
        self.ddcService = ddcService
        self.settingsStore = settingsStore
        self.showHiDPIModes = settingsStore.showHiDPIByDefault
    }

    func loadState() async {
        // Display name
        name = id.localizedName

        // Hardware facts
        let hw = DisplayHardware.query(displayID: id, ddcService: ddcService)
        hardware = hw

        // Brightness
        let caps = brightnessController.capabilities(for: id)
        brightnessCapabilities = caps
        brightness = brightnessController.getBrightness(for: id)

        // Resolution modes
        availableModes = resolutionController.availableModes(for: id, includeHiDPI: showHiDPIModes)
        currentMode = resolutionController.currentMode(for: id)

        // Color profiles
        colorProfiles = colorProfileController.availableProfiles()
        currentColorProfile = colorProfileController.currentProfile(for: id)

        // DDC input sources for external displays
        if hw.hasDDC {
            await loadInputSources(modelNumber: hw.modelNumber)
        }
    }

    // Called on slider change — immediate UI update, debounced hardware call
    func setBrightness(_ value: Double) {
        brightness = value
        brightnessDebounceTask?.cancel()
        brightnessDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            try? await brightnessController.setBrightness(value, for: id)
            settingsStore.setPreferredBrightness(value, for: displayUUID)
        }
    }

    func setResolution(_ mode: ResolutionMode) async {
        isApplyingChange = true
        defer { isApplyingChange = false }
        do {
            try resolutionController.applyMode(mode, to: id)
            currentMode = mode
            settingsStore.setPreferredResolution(
                width: mode.width, height: mode.height,
                refreshRate: mode.refreshRate, isHiDPI: mode.isHiDPI,
                for: displayUUID
            )
        } catch {
            // Reload current mode on failure
            currentMode = resolutionController.currentMode(for: id)
        }
    }

    func setColorProfile(_ profile: ColorProfile) async {
        isApplyingChange = true
        defer { isApplyingChange = false }
        do {
            try colorProfileController.setProfile(profile, for: id)
            currentColorProfile = profile
            settingsStore.setPreferredColorProfileURL(profile.url, for: displayUUID)
        } catch {}
    }

    func setInputSource(_ source: InputSource) async {
        isApplyingChange = true
        defer { isApplyingChange = false }
        do {
            try await ddcService.writeValue(displayID: id, code: .inputSource, value: source.vcpValue)
            currentInputSource = source
        } catch {}
    }

    // MARK: - Private

    private func loadInputSources(modelNumber: UInt32) async {
        // Probe common input source VCP values
        if let result = try? await ddcService.readValue(displayID: id, code: .inputSource) {
            let current = result.currentValue
            // Build list of known inputs based on common VCP values
            let sources: [InputSource] = InputSourceValue.allCases.map { inputValue in
                let label = settingsStore.inputSourceLabel(monitorModel: modelNumber, vcpValue: inputValue.rawValue)
                    ?? inputValue.displayName
                return InputSource(vcpValue: inputValue.rawValue, label: label)
            }
            inputSources = sources
            currentInputSource = sources.first { $0.vcpValue == current }
        }
    }
}
