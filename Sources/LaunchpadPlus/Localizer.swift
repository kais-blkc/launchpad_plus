import AppKit

struct AppLanguage: Identifiable, Hashable {
    let code: String
    let nativeName: String
    var id: String { code }
}

/// Переводы из `<код>.lproj/Localizable.strings`. Язык меняется на лету, без перезапуска.
@MainActor
final class Localizer: ObservableObject {
    static let shared = Localizer()
    static let systemChoice = "system"

    /// Названия пишутся на самих языках и не переводятся.
    static let languages: [AppLanguage] = [
        .init(code: "en", nativeName: "English"),
        .init(code: "zh-Hans", nativeName: "简体中文"),
        .init(code: "es", nativeName: "Español"),
        .init(code: "fr", nativeName: "Français"),
        .init(code: "de", nativeName: "Deutsch"),
        .init(code: "ja", nativeName: "日本語"),
        .init(code: "pt-BR", nativeName: "Português (Brasil)"),
        .init(code: "ru", nativeName: "Русский"),
        .init(code: "ko", nativeName: "한국어"),
        .init(code: "it", nativeName: "Italiano"),
        .init(code: "tr", nativeName: "Türkçe"),
    ]

    /// Выбор пользователя: «system» или код языка.
    @Published private(set) var choice: String
    /// Фактически применённый язык.
    private(set) var code = "en"
    private(set) var locale = Locale(identifier: "en")
    private(set) var dateFormatter = DateFormatter()
    private(set) var relativeFormatter = RelativeDateTimeFormatter()

    private var table: [String: String] = [:]
    private var fallback: [String: String] = [:]

    private init() {
        choice = UserDefaults.standard.string(forKey: "language") ?? Self.systemChoice
        fallback = Self.load("en")
        apply()
    }

    func setChoice(_ new: String) {
        UserDefaults.standard.set(new, forKey: "language")
        choice = new
        apply()
    }

    // MARK: - Перевод

    func t(_ key: String) -> String { table[key] ?? fallback[key] ?? key }

    func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: locale, arguments: args)
    }

    /// «1 запуск / 2 запуска / 5 запусков» — по правилам множественного числа текущего языка.
    func launches(_ n: Int) -> String {
        let key = "launches." + Self.pluralCategory(n, code: code)
        let template = table[key] ?? table["launches.other"] ?? fallback["launches.other"] ?? "%d"
        return String(format: template, locale: locale, n)
    }

    private static func pluralCategory(_ n: Int, code: String) -> String {
        switch code {
        case "ru":
            let m10 = n % 10, m100 = n % 100
            if m10 == 1 && m100 != 11 { return "one" }
            if (2...4).contains(m10) && !(12...14).contains(m100) { return "few" }
            return "many"
        case "zh-Hans", "ja", "ko": return "other"
        case "fr", "pt-BR": return n == 0 || n == 1 ? "one" : "other"
        default: return n == 1 ? "one" : "other"
        }
    }

    // MARK: - Загрузка

    private func apply() {
        code = choice == Self.systemChoice ? Self.systemLanguage() : choice
        if !Self.languages.contains(where: { $0.code == code }) { code = "en" }
        locale = Locale(identifier: code)
        table = Self.load(code)

        dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.locale = locale
        relativeFormatter.unitsStyle = .full
    }

    private static func load(_ code: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                                        subdirectory: nil, localization: code),
              let dict = NSDictionary(contentsOf: url) as? [String: String] else { return [:] }
        return dict
    }

    /// Первый поддерживаемый язык из системных предпочтений, иначе английский.
    private static func systemLanguage() -> String {
        for tag in Locale.preferredLanguages {
            let lower = tag.lowercased()
            if lower.hasPrefix("zh") { return "zh-Hans" }
            if lower.hasPrefix("pt") { return "pt-BR" }
            let base = String(lower.prefix(2))
            if languages.contains(where: { $0.code == base }) { return base }
        }
        return "en"
    }
}

/// Короткие вызовы для вью и меню.
@MainActor func L(_ key: String) -> String { Localizer.shared.t(key) }
@MainActor func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: Localizer.shared.t(key), locale: Localizer.shared.locale, arguments: args)
}
