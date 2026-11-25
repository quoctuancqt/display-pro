import AppKit
import SwiftUI

/// Shows window thumbnails when the pointer rests on a Dock icon; resting on
/// a thumbnail peeks at the real window in place, clicking focuses it.
@MainActor
final class DockPreviewController {

    private let inventory: WindowInventory
    private let thumbnails: Thumbnails
    private let dock = DockObserver()
    private let model = DockPreviewModel()
    private let peek = WindowPeekOverlay()

    private var panel: OverlayPanel?
    private var currentPID: pid_t?
    /// Hovered Dock icon in Cocoa coordinates.
    private var itemRect: CGRect = .null
    private var pollTimer: Timer?
    private var outsideSince: Date?
    private var hoverWork: DispatchWorkItem?
    private var peekWork: DispatchWorkItem?

    /// Pause on an icon before the panel appears.
    private let showDelay: TimeInterval = 0.25
    /// Pause on a thumbnail before peeking at the window.
    private let peekDelay: TimeInterval = 0.6
    /// How long the pointer may be outside icon + panel before hiding.
    private let hideGrace: TimeInterval = 0.3

    init(inventory: WindowInventory, thumbnails: Thumbnails) {
        self.inventory = inventory
        self.thumbnails = thumbnails
        dock.onHover = { [weak self] item in self?.dockHoverChanged(item) }
    }

    var isRunning: Bool { dock.isRunning }

    @discardableResult
    func start() -> Bool { dock.start() }

    func stop() {
        dock.stop()
        hide()
    }

    // MARK: Dock hover

    private func dockHoverChanged(_ item: DockObserver.Item?) {
        hoverWork?.cancel()

        guard let item else {
            // Pointer left the icons — maybe toward the panel. The poll timer
            // decides whether to hide.
            return
        }

        guard let app = item.app else {
            hide()
            return
        }

        let rect = ScreenGeometry.cocoa(fromCG: item.frame)
        if isVisible && currentPID == app.processIdentifier {
            itemRect = rect
            return
        }

        // Switching between icons while the panel is up updates immediately.
        let delay = isVisible ? 0 : showDelay
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.show(app: app, itemRect: rect) }
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private var isVisible: Bool { panel?.isVisible == true }

    // MARK: Show / hide

    private func show(app: NSRunningApplication, itemRect rect: CGRect) {
        // Make sure the pointer is still over that icon.
        guard rect.insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation) else { return }

        let windows = inventory.windows(forPID: app.processIdentifier)
        guard !windows.isEmpty, let screen = ScreenGeometry.screen(for: rect) ?? NSScreen.main else {
            hide()
            return
        }

        cancelPeek()
        currentPID = app.processIdentifier
        itemRect = rect

        let edge = dockEdge(itemRect: rect, screen: screen)
        let bounds: CGSize
        let maxColumns: Int
        switch edge {
        case .bottom:
            bounds = CGSize(width: screen.visibleFrame.width - 40, height: screen.visibleFrame.height * 0.6)
            maxColumns = .max
        case .left, .right:
            bounds = CGSize(width: screen.visibleFrame.width * 0.5, height: screen.visibleFrame.height - 40)
            maxColumns = 2
        }
        let layout = TileLayout.fit(count: windows.count, in: bounds, maxColumns: maxColumns, preferredWidth: 200)

        model.appName = app.localizedName ?? ""
        model.appIcon = app.icon
        model.windows = windows
        model.hovered = nil
        model.thumbSize = layout.thumb
        model.columns = layout.columns
        thumbnails.load(windows, maxDimension: layout.thumb.width)

        let panel = self.panel ?? OverlayPanel(interactive: true)
        self.panel = panel
        let size = panel.setContent(
            DockPreviewView(
                model: model,
                thumbnails: thumbnails,
                onHover: { [weak self] window in self?.thumbnailHoverChanged(window) },
                onClick: { [weak self] window in self?.activate(window) }
            )
        )

        let gap: CGFloat = 8
        var origin: CGPoint
        switch edge {
        case .bottom: origin = CGPoint(x: rect.midX - size.width / 2, y: rect.maxY + gap)
        case .left: origin = CGPoint(x: rect.maxX + gap, y: rect.midY - size.height / 2)
        case .right: origin = CGPoint(x: rect.minX - gap - size.width, y: rect.midY - size.height / 2)
        }
        let limit = screen.frame.insetBy(dx: 8, dy: 8)
        origin.x = min(max(origin.x, limit.minX), limit.maxX - size.width)
        origin.y = min(max(origin.y, limit.minY), limit.maxY - size.height)

        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        startPolling()
    }

    private func hide() {
        hoverWork?.cancel()
        cancelPeek()
        stopPolling()
        panel?.orderOut(nil)
        thumbnails.cancel()
        currentPID = nil
        itemRect = .null
    }

    // MARK: Pointer tracking

    private func startPolling() {
        outsideSince = nil
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        guard let panel, panel.isVisible else { return }
        let p = NSEvent.mouseLocation
        // The union also covers the gap between the icon and the panel.
        let zone = panel.frame.union(itemRect).insetBy(dx: -6, dy: -6)
        if zone.contains(p) {
            outsideSince = nil
        } else if let since = outsideSince {
            if Date().timeIntervalSince(since) > hideGrace { hide() }
        } else {
            outsideSince = Date()
        }
    }

    // MARK: Thumbnails

    private func thumbnailHoverChanged(_ window: WindowInfo?) {
        model.hovered = window?.id
        cancelPeek()
        guard let window else { return }

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.startPeek(window) }
        }
        peekWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + peekDelay, execute: work)
    }

    private func startPeek(_ window: WindowInfo) {
        guard model.hovered == window.id, window.placement != .minimized else { return }
        let maxDimension = max(window.frame.width, window.frame.height)
        Task { [weak self] in
            guard let self else { return }
            let image = await self.thumbnails.capture(window, maxDimension: maxDimension)
                ?? self.thumbnails.images[window.id]
            guard let image, self.model.hovered == window.id, self.isVisible else { return }
            self.peek.show(window, image: image)
        }
    }

    private func cancelPeek() {
        peekWork?.cancel()
        peekWork = nil
        peek.hide()
    }

    private func activate(_ window: WindowInfo) {
        hide()
        inventory.noteFocused(window.id)
        WindowFocuser.focus(window)
    }

    // MARK: Dock geometry

    private enum Edge { case bottom, left, right }

    private func dockEdge(itemRect rect: CGRect, screen: NSScreen) -> Edge {
        if let orientation = UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") {
            switch orientation {
            case "left": return .left
            case "right": return .right
            default: return .bottom
            }
        }
        let f = screen.frame
        let distances: [(Edge, CGFloat)] = [
            (.bottom, rect.minY - f.minY),
            (.left, rect.minX - f.minX),
            (.right, f.maxX - rect.maxX),
        ]
        return distances.min { $0.1 < $1.1 }!.0
    }
}
