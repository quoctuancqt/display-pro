import AppKit
import SwiftUI

@MainActor
final class SwitcherModel: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var selection: Int = 0
    @Published var thumbSize = CGSize(width: 220, height: 138)
    @Published var columns = 1
}

/// ⌘Tab window switcher: every window across Spaces and displays.
@MainActor
final class WindowSwitcherController {

    private let inventory: WindowInventory
    private let thumbnails: Thumbnails
    private let tap = SwitcherHotkeyTap()
    private let model = SwitcherModel()
    private var panel: OverlayPanel?
    private var showWorkItem: DispatchWorkItem?
    /// Hover only selects once the pointer has moved since the panel appeared,
    /// so a tile that happens to be under a resting cursor doesn't steal focus.
    private var mouseAtShow: CGPoint?

    /// A quick ⌘Tab tap switches without flashing the UI, like the system one.
    private let showDelay: TimeInterval = 0.12

    init(inventory: WindowInventory, thumbnails: Thumbnails) {
        self.inventory = inventory
        self.thumbnails = thumbnails
        tap.onAction = { [weak self] action in self?.handle(action) }
    }

    var isRunning: Bool { tap.isInstalled }

    @discardableResult
    func start() -> Bool { tap.install() }

    func stop() {
        dismiss()
        tap.uninstall()
    }

    // MARK: Actions

    private func handle(_ action: SwitcherHotkeyTap.Action) {
        switch action {
        case .begin(let reverse): begin(reverse: reverse)
        case .next: move(by: 1)
        case .previous: move(by: -1)
        case .up: move(by: -model.columns, wrap: false)
        case .down: move(by: model.columns, wrap: false)
        case .commit: commit()
        case .cancel: dismiss()
        }
    }

    private func begin(reverse: Bool) {
        let windows = inventory.allWindows()
        guard !windows.isEmpty else {
            tap.isActive = false
            return
        }

        model.windows = windows
        if windows.count == 1 {
            model.selection = 0
        } else {
            model.selection = reverse ? windows.count - 1 : 1
        }

        let screen = ScreenGeometry.screenUnderMouse
        let bounds = CGSize(width: screen.visibleFrame.width * 0.9 - 32,
                            height: screen.visibleFrame.height * 0.85 - 32)
        let layout = TileLayout.fit(count: windows.count, in: bounds, maxColumns: 8, preferredWidth: 220)
        model.thumbSize = layout.thumb
        model.columns = layout.columns

        thumbnails.load(windows, maxDimension: layout.thumb.width)

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.showPanel(on: screen) }
        }
        showWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: work)
    }

    private func move(by delta: Int, wrap: Bool = true) {
        let count = model.windows.count
        guard count > 0 else { return }
        var next = model.selection + delta
        if wrap {
            next = ((next % count) + count) % count
        } else {
            next = min(max(next, 0), count - 1)
        }
        model.selection = next
    }

    private func commit() {
        let target = model.windows.indices.contains(model.selection) ? model.windows[model.selection] : nil
        dismiss()
        if let target {
            inventory.noteFocused(target.id)
            WindowFocuser.focus(target)
        }
    }

    private func select(_ index: Int, commit shouldCommit: Bool) {
        guard model.windows.indices.contains(index) else { return }
        if !shouldCommit, let start = mouseAtShow {
            let p = NSEvent.mouseLocation
            guard hypot(p.x - start.x, p.y - start.y) > 2 else { return }
            mouseAtShow = nil
        }
        model.selection = index
        if shouldCommit { commit() }
    }

    private func dismiss() {
        showWorkItem?.cancel()
        showWorkItem = nil
        tap.isActive = false
        panel?.orderOut(nil)
        thumbnails.cancel()
    }

    // MARK: Panel

    private func showPanel(on screen: NSScreen) {
        guard tap.isActive else { return }

        let panel = self.panel ?? OverlayPanel(interactive: true)
        self.panel = panel

        let size = panel.setContent(
            WindowSwitcherView(
                model: model,
                thumbnails: thumbnails,
                onHover: { [weak self] index in self?.select(index, commit: false) },
                onClick: { [weak self] index in self?.select(index, commit: true) }
            )
        )

        let visible = screen.visibleFrame
        let origin = CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        panel.setFrameOrigin(origin)
        mouseAtShow = NSEvent.mouseLocation
        panel.orderFrontRegardless()
    }
}
