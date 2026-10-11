import ServiceManagement

/// Автозапуск при входе в систему (macOS 13+ — SMAppService, без helper-приложения).
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Launchpad+: не удалось изменить автозапуск: \(error)")
        }
    }
}
