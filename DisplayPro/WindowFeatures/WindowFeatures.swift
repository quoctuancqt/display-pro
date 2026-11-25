import AppKit
import Combine

/// Owns the Dock preview and ⌘Tab switcher, their on/off settings and the
/// permissions they depend on. Shared by both app entry points.
@MainActor
final class WindowFeatures: ObservableObject {

    static let shared = WindowFeatures()

    @Published var dockPreviewEnabled: Bool {
        didSet {
            guard dockPreviewEnabled != oldValue else { return }
            defaults.set(dockPreviewEnabled, forKey: Keys.dockPreview)
            if dockPreviewEnabled { requestMissingPermissions() }
            apply()
        }
    }

    @Published var windowSwitcherEnabled: Bool {
        didSet {
            guard windowSwitcherEnabled != oldValue else { return }
            defaults.set(windowSwitcherEnabled, forKey: Keys.windowSwitcher)
            if windowSwitcherEnabled { requestMissingPermissions() }
            apply()
        }
    }

    @Published private(set) var hasAccessibility = Permissions.hasAccessibility
    @Published private(set) var hasScreenRecording = Permissions.hasScreenRecording
    @Published private(set) var dockPreviewRunning = false
    @Published private(set) var windowSwitcherRunning = false

    private enum Keys {
        static let dockPreview = "DisplayPro.dockPreview"
        static let windowSwitcher = "DisplayPro.windowSwitcher"
    }

    private let defaults = UserDefaults.standard
    private let inventory = WindowInventory()
    private let thumbnails = Thumbnails()
    private lazy var dockPreview = DockPreviewController(inventory: inventory, thumbnails: thumbnails)
    private lazy var switcher = WindowSwitcherController(inventory: inventory, thumbnails: thumbnails)

    private var started = false
    private var permissionTimer: Timer?
    private var terminateObserver: NSObjectProtocol?

    private init() {
        dockPreviewEnabled = defaults.bool(forKey: Keys.dockPreview)
        windowSwitcherEnabled = defaults.bool(forKey: Keys.windowSwitcher)
    }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true

        // If a previous run died while the switcher was on, the system ⌘Tab
        // may still be disabled. Restore it; installing the tap disables it again.
        WindowSPI.setNativeCommandTabEnabled(true)

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
        atexit { WindowSPI.setNativeCommandTabEnabled(true) }

        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer

        apply()
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        if windowSwitcherRunning { switcher.stop() }
        if dockPreviewRunning { dockPreview.stop() }
        windowSwitcherRunning = false
        dockPreviewRunning = false
        WindowSPI.setNativeCommandTabEnabled(true)
    }

    // MARK: Permissions

    func requestAccessibility() { Permissions.requestAccessibility() }
    func requestScreenRecording() { Permissions.requestScreenRecording() }

    private func requestMissingPermissions() {
        if !Permissions.hasAccessibility {
            Permissions.requestAccessibility()
        } else if !Permissions.hasScreenRecording {
            Permissions.requestScreenRecording()
        }
    }

    private func refreshPermissions() {
        let ax = Permissions.hasAccessibility
        let sr = Permissions.hasScreenRecording
        guard ax != hasAccessibility || sr != hasScreenRecording else { return }
        hasAccessibility = ax
        hasScreenRecording = sr
        apply()
    }

    // MARK: Apply

    /// Starts or stops each feature to match its setting and permissions.
    private func apply() {
        guard started else { return }
        hasAccessibility = Permissions.hasAccessibility
        hasScreenRecording = Permissions.hasScreenRecording

        let wantSwitcher = windowSwitcherEnabled && hasAccessibility
        if wantSwitcher && !windowSwitcherRunning {
            windowSwitcherRunning = switcher.start()
        } else if !wantSwitcher && windowSwitcherRunning {
            switcher.stop()
            windowSwitcherRunning = false
        }

        let wantDock = dockPreviewEnabled && hasAccessibility
        if wantDock && !dockPreviewRunning {
            dockPreviewRunning = dockPreview.start()
        } else if !wantDock && dockPreviewRunning {
            dockPreview.stop()
            dockPreviewRunning = false
        }
    }
}
