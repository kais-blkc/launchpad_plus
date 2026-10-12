import AppKit
import SwiftUI

/// Окно без рамки: ловит клавиатуру и закрывается по Esc.
final class OverlayWindow: NSWindow {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// Показывает/скрывает большое окно с размытым фоном поверх всего.
@MainActor
final class OverlayController {
    private var window: OverlayWindow?
    private let store = AppStore()
    private var keyMonitor: Any?

    init() {
        store.reload()      // прогрев: сканируем и кэшируем иконки при старте
        window = makeWindow()
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        let screen = screenUnderCursor()
        store.query = ""
        store.reload()
        let window = self.window ?? makeWindow()
        self.window = window
        window.setFrame(screen.frame, display: true)
        window.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; window.animator().alphaValue = 1 }
    }

    func hide() {
        guard let window, window.isVisible else { return }
        removeKeyMonitor()
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.12; window.animator().alphaValue = 0 }) {
            window.orderOut(nil)
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let (code, mods) = (event.keyCode, event.modifierFlags)
            let handled = MainActor.assumeIsolated { self?.handleKey(code: code, modifiers: mods) ?? false }
            return handled ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Стрелки двигают выделение, Enter запускает. Остальное идёт в поле поиска.
    private func handleKey(code: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard modifiers.intersection([.command, .control, .option]).isEmpty else { return false }
        switch code {
        case 123: store.move(dx: -1, dy: 0)
        case 124: store.move(dx: 1, dy: 0)
        case 125: store.move(dx: 0, dy: 1)
        case 126: store.move(dx: 0, dy: -1)
        case 36, 76: if store.launchSelected() { hide() }
        default: return false
        }
        return true
    }

    private func makeWindow() -> OverlayWindow {
        let window = OverlayWindow(contentRect: .zero, styleMask: [.borderless],
                                   backing: .buffered, defer: false)
        window.level = .statusBar   // выше Dock и меню-бара, но ниже меню (.popUpMenu), иначе выпадающие списки прячутся под окном
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.onCancel = { [weak self] in self?.hide() }

        let blur = NSVisualEffectView()
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active

        let host = NSHostingView(rootView: RootView(store: store,
                                         onBackgroundClick: { [weak self] in self?.hide() },
                                         onLaunch: { [weak self] in self?.hide() }))
        host.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            host.topAnchor.constraint(equalTo: blur.topAnchor),
            host.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])
        window.contentView = blur

        // Закрываться, когда пользователь переключился в другое приложение
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                               object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
        return window
    }

    private func screenUnderCursor() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
