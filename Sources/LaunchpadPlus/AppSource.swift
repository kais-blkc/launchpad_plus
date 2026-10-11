enum AppSource: Int, CaseIterable, Hashable {
    case appStore, brew, manual, system

    @MainActor var title: String { L("source.\(self)") }

    /// Подсказка при наведении: что именно скрывается за названием.
    @MainActor var hint: String { L("source.\(self).hint") }
}
