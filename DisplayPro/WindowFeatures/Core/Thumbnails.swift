import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Captures and caches window images with ScreenCaptureKit.
///
/// Off-Space windows keep a backing store in the window server, so they can
/// usually be captured too. Minimized windows often can't; for those the last
/// cached image (if any) is kept and views fall back to the app icon.
@MainActor
final class Thumbnails: ObservableObject {

    @Published private(set) var images: [CGWindowID: CGImage] = [:]

    private var scWindows: [CGWindowID: SCWindow] = [:]
    private var contentFetchedAt: Date = .distantPast
    private var loadTask: Task<Void, Never>?

    /// Captures thumbnails for `windows` (in order), publishing each as it
    /// arrives. Cancels any load still in flight.
    func load(_ windows: [WindowInfo], maxDimension: CGFloat) {
        loadTask?.cancel()
        guard Permissions.hasScreenRecording, !windows.isEmpty else { return }

        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshContent(ifMissing: windows.map(\.id))
            for window in windows {
                if Task.isCancelled { return }
                if let image = await self.capture(window, maxDimension: maxDimension) {
                    self.images[window.id] = image
                }
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    /// Captures one window at up to `maxDimension` points on its longer side.
    func capture(_ window: WindowInfo, maxDimension: CGFloat) async -> CGImage? {
        guard Permissions.hasScreenRecording else { return nil }
        if scWindows[window.id] == nil {
            await refreshContent(ifMissing: [window.id])
        }
        guard let scWindow = scWindows[window.id] else { return nil }

        let size = scWindow.frame.size
        guard size.width > 0, size.height > 0 else { return nil }

        let backing = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        let scale = min(1, maxDimension / max(size.width, size.height)) * backing

        let config = SCStreamConfiguration()
        config.width = max(1, Int(size.width * scale))
        config.height = max(1, Int(size.height * scale))
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        config.captureResolution = .best

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            windowFeaturesLog.debug("Capture failed for window \(window.id): \(error.localizedDescription)")
            return nil
        }
    }

    /// Refreshes the SCWindow table when it is stale or lacks a needed window.
    private func refreshContent(ifMissing ids: [CGWindowID]) async {
        let fresh = Date().timeIntervalSince(contentFetchedAt) < 1
        if fresh && ids.allSatisfy({ scWindows[$0] != nil }) { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            var table: [CGWindowID: SCWindow] = [:]
            for w in content.windows { table[w.windowID] = w }
            scWindows = table
            contentFetchedAt = Date()
            // Drop images of windows that no longer exist.
            images = images.filter { table[$0.key] != nil }
        } catch {
            windowFeaturesLog.error("SCShareableContent failed: \(error.localizedDescription)")
        }
    }
}
