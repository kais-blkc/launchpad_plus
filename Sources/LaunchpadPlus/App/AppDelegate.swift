import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let overlay = OverlayController()
    private let hotKey = GlobalHotKey()
    private let gesture = TrackpadGesture()
    private var languageObserver: AnyCancellable?
    private var launchAtLoginItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupEditMenu()
        // смена языка: меню в верхней панели пересоздаётся сразу
        languageObserver = Localizer.shared.$choice.dropFirst().sink { [weak self] _ in
            MainActor.assumeIsolated {
                self?.buildStatusMenu()
                self?.setupEditMenu()
            }
        }
        gesture.onPinchIn = { [weak self] in self?.overlay.show() }
        gesture.onPinchOut = { [weak self] in self?.overlay.hide() }
        gesture.start()
        // ⌥Space
        hotKey.register(keyCode: 49, modifiers: .option) { [weak self] in
            self?.overlay.toggle()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill",
                                           accessibilityDescription: "Launchpad+")
        buildStatusMenu()
    }

    private func buildStatusMenu() {
        let loc = Localizer.shared
        let menu = NSMenu()
        menu.addItem(withTitle: L("menu.show"), action: #selector(show), keyEquivalent: "").target = self

        let languageMenu = NSMenu()
        let current = loc.choice
        let system = languageMenu.addItem(withTitle: L("settings.system"), action: #selector(selectLanguage(_:)), keyEquivalent: "")
        system.target = self
        system.representedObject = Localizer.systemChoice
        system.state = current == Localizer.systemChoice ? .on : .off
        languageMenu.addItem(.separator())
        for language in Localizer.languages {
            let item = languageMenu.addItem(withTitle: language.nativeName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.code
            item.state = current == language.code ? .on : .off
        }
        menu.addItem(withTitle: L("menu.language"), action: nil, keyEquivalent: "").submenu = languageMenu

        menu.addItem(.separator())
        let login = menu.addItem(withTitle: L("settings.launchAtLogin"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        launchAtLoginItem = login
        menu.addItem(withTitle: L("menu.quit"), action: #selector(quit), keyEquivalent: "q").target = self
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Галочка автозапуска могла измениться из окна приложений — обновляем при открытии меню.
    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    /// У приложения без Dock нет меню «Правка», а ⌘A/C/V/X/Z работают именно через него.
    private func setupEditMenu() {
        let edit = NSMenu(title: L("edit.title"))
        edit.addItem(withTitle: L("edit.undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: L("edit.redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: L("edit.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("edit.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("edit.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("edit.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let mainMenu = NSMenu()
        mainMenu.addItem(withTitle: L("edit.title"), action: nil, keyEquivalent: "").submenu = edit
        NSApp.mainMenu = mainMenu
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        Localizer.shared.setChoice(code)
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }

    @objc private func show() { overlay.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
