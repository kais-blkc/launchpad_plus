import AppKit
import SwiftUI

enum SortOption: CaseIterable {
    case name, dateAdded, mostUsed, recentlyUsed, source, size

    @MainActor var title: String { L("sort.\(self)") }
}

/// nil — «Все»
typealias SourceFilter = AppSource?

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var apps: [AppItem] = [] { didSet { updateFiltered() } }
    @Published private(set) var filtered: [AppItem] = []
    @Published var query = "" {
        didSet {
            guard query != oldValue else { return }
            updateFiltered()
            // при поиске сразу подсвечиваем первый результат, чтобы Enter запускал его
            selectedID = query.trimmingCharacters(in: .whitespaces).isEmpty ? nil : filtered.first?.id
        }
    }
    @Published var selectedID: String?
    @Published var iconSize: Double = {
        let v = UserDefaults.standard.double(forKey: "iconSize")
        return v == 0 ? 84 : v
    }() { didSet { UserDefaults.standard.set(iconSize, forKey: "iconSize") } }

    /// Число колонок сетки — выставляет вью, нужно для навигации стрелками.
    var columns = 6
    @Published var sort: SortOption = .name { didSet { updateFiltered() } }
    @Published var reversed = false { didSet { updateFiltered() } }
    @Published var filter: SourceFilter = nil { didSet { updateFiltered() } }
    @Published var colorFilter: IconColor? = nil { didSet { updateFiltered() } }

    func count(for source: SourceFilter) -> Int {
        guard let source else { return apps.count }
        return apps.reduce(0) { $0 + ($1.source == source ? 1 : 0) }
    }

    private func updateFiltered() {
        let q = query.trimmingCharacters(in: .whitespaces)
        var list = apps
        if let filter { list = list.filter { $0.source == filter } }
        if let colorFilter { list = list.filter { $0.color == colorFilter } }
        if !q.isEmpty { list = list.filter { $0.name.localizedCaseInsensitiveContains(q) } }
        list.sort(by: comparator(sort))
        if reversed { list.reverse() }
        filtered = list
        if let id = selectedID, !list.contains(where: { $0.id == id }) { selectedID = nil }
    }

    // MARK: - Подпись под иконкой по текущей сортировке

    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    func caption(for app: AppItem) -> String? {
        switch sort {
        case .name:
            return nil
        case .size:
            return app.size > 0 ? Self.sizeFormatter.string(fromByteCount: app.size) : nil
        case .dateAdded:
            return app.dateAdded.map { Localizer.shared.dateFormatter.string(from: $0) }
        case .mostUsed:
            return Localizer.shared.launches(app.useCount)
        case .recentlyUsed:
            return app.lastUsed.map { Localizer.shared.relativeFormatter.localizedString(for: $0, relativeTo: Date()) } ?? L("caption.neverUsed")
        case .source:
            return app.source.title
        }
    }

    func resetFilters() {
        withAnimation(.snappy(duration: 0.25)) { filter = nil; colorFilter = nil }
    }

    // MARK: - Клавиатура

    func move(dx: Int, dy: Int) {
        guard !filtered.isEmpty else { return }
        guard let id = selectedID, let i = filtered.firstIndex(where: { $0.id == id }) else {
            selectedID = filtered.first?.id
            return
        }
        var target = i + dx + dy * columns
        // вниз с неполной нижней строки — на последний элемент, а не «никуда»
        if dy > 0, target >= filtered.count, i / columns < (filtered.count - 1) / columns { target = filtered.count - 1 }
        selectedID = filtered[min(max(target, 0), filtered.count - 1)].id
    }

    /// Запускает выделенное (или первое, если выделения нет). false — запускать нечего.
    func launchSelected() -> Bool {
        guard let app = filtered.first(where: { $0.id == selectedID }) ?? filtered.first else { return false }
        launch(app)
        return true
    }

    // MARK: - Действия контекстного меню

    /// Открывает Finder на папке с приложением (обычно «Программы») с выделенным .app.
    /// Окно Launchpad+ перекрывает Finder, поэтому вызывать после того, как оно скрылось.
    func reveal(_ app: AppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([app.url])
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?
            .activate(options: [.activateAllWindows])
    }

    func copyPath(_ app: AppItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(app.url.path, forType: .string)
    }

    func moveToTrash(_ app: AppItem) {
        NSWorkspace.shared.recycle([app.url]) { [weak self] _, error in
            guard error == nil else { return }
            Task { @MainActor in self?.reload() }
        }
    }

    /// Порядок «по умолчанию» для каждого вида сортировки (новые/частые/большие — первыми).
    private func comparator(_ option: SortOption) -> (AppItem, AppItem) -> Bool {
        let byName: (AppItem, AppItem) -> Bool = { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        switch option {
        case .name:
            return byName
        case .dateAdded:
            return { ($0.dateAdded ?? .distantPast, $1.name) > ($1.dateAdded ?? .distantPast, $0.name) }
        case .mostUsed:
            return { $0.useCount != $1.useCount ? $0.useCount > $1.useCount : byName($0, $1) }
        case .recentlyUsed:
            return {
                let (a, b) = ($0.lastUsed ?? .distantPast, $1.lastUsed ?? .distantPast)
                return a != b ? a > b : byName($0, $1)
            }
        case .source:
            return { $0.source != $1.source ? $0.source.rawValue < $1.source.rawValue : byName($0, $1) }
        case .size:
            return { $0.size != $1.size ? $0.size > $1.size : byName($0, $1) }
        }
    }

    func reload() {
        Task.detached(priority: .userInitiated) {
            let found = AppScanner.scan()
            await self.publish(found)
            // размеры считаются дольше — подтягиваем вторым проходом
            let sized = AppScanner.fillSizes(found)
            await self.publish(sized)
        }
    }

    /// Не трогаем UI, если список не изменился.
    private func publish(_ list: [AppItem]) {
        // между проходами пользователь мог увидеть размеры — не затираем их нулями
        let merged = list.map { item -> AppItem in
            guard item.size == 0, let old = apps.first(where: { $0.url == item.url }) else { return item }
            var copy = item; copy.size = old.size; return copy
        }
        if merged != apps { apps = merged }
    }

    func launch(_ app: AppItem) {
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }
}
