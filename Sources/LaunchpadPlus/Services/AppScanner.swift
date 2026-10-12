import AppKit
import CoreServices

/// Находит установленные .app и собирает метаданные (источник, даты, частоту, размер).
enum AppScanner {
    private static let roots = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications",
    ]
    private static let caskrooms = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]
    private static let maxDepth = 2 // /Applications/Utilities/X.app, /Applications/Folder/X.app

    // MARK: - Кэш тяжёлых вычислений (иконка, размер), ключ — путь + дата изменения бандла

    private struct Cached { let mtime: Date?; let icon: NSImage?; let color: IconColor?; let size: Int64? }
    private static var cache: [String: Cached] = [:]
    private static let lock = NSLock()

    private static func cached(_ url: URL, mtime: Date?) -> Cached? {
        lock.lock(); defer { lock.unlock() }
        guard let c = cache[url.path], c.mtime == mtime else { return nil }
        return c
    }
    private static func store(_ url: URL, mtime: Date?, icon: NSImage? = nil, color: IconColor? = nil, size: Int64? = nil) {
        lock.lock(); defer { lock.unlock() }
        let old = cache[url.path]?.mtime == mtime ? cache[url.path] : nil
        cache[url.path] = Cached(mtime: mtime, icon: icon ?? old?.icon, color: color ?? old?.color, size: size ?? old?.size)
    }

    // MARK: - Скан

    /// Быстрый проход: без размеров (они считаются отдельно в `fillSizes`).
    static func scan() -> [AppItem] {
        var seen = Set<String>()
        var urls: [URL] = []
        for root in roots {
            collect(URL(fileURLWithPath: root), depth: 0, into: &urls, seen: &seen)
        }

        let brewNames = brewAppNames()
        var items = [AppItem?](repeating: nil, count: urls.count)
        let outLock = NSLock()
        DispatchQueue.concurrentPerform(iterations: urls.count) { i in
            let item = makeItem(urls[i], brewNames: brewNames)
            outLock.lock(); items[i] = item; outLock.unlock()
        }
        return items.compactMap { $0 }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Считает размеры бандлов параллельно; результат кэшируется до изменения приложения.
    static func fillSizes(_ apps: [AppItem]) -> [AppItem] {
        var result = apps
        let outLock = NSLock()
        DispatchQueue.concurrentPerform(iterations: apps.count) { i in
            let url = apps[i].url
            let mtime = modificationDate(url)
            let size: Int64
            if let hit = cached(url, mtime: mtime)?.size {
                size = hit
            } else {
                size = directorySize(url)
                store(url, mtime: mtime, size: size)
            }
            outLock.lock(); result[i].size = size; outLock.unlock()
        }
        return result
    }

    private static func collect(_ dir: URL, depth: Int, into urls: inout [URL], seen: inout Set<String>) {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return }

        for url in entries {
            if url.pathExtension == "app" {
                let real = url.resolvingSymlinksInPath().path
                if seen.insert(real).inserted { urls.append(url) }
            } else if depth + 1 < maxDepth,
                      (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                collect(url, depth: depth + 1, into: &urls, seen: &seen)
            }
        }
    }

    // MARK: - Элемент

    private static func makeItem(_ url: URL, brewNames: Set<String>) -> AppItem {
        let bundle = Bundle(url: url)
        let info = bundle?.infoDictionary
        let localized = bundle?.localizedInfoDictionary
        let name = (localized?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleDisplayName"] as? String)
            ?? FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        let bundleID = bundle?.bundleIdentifier

        let mtime = modificationDate(url)
        let icon: NSImage
        let color: IconColor
        if let hit = cached(url, mtime: mtime), let hitIcon = hit.icon, let hitColor = hit.color {
            (icon, color) = (hitIcon, hitColor)
        } else {
            (icon, color) = renderIcon(url)
            store(url, mtime: mtime, icon: icon, color: color)
        }

        let meta = spotlightMeta(url)
        return AppItem(
            url: url, name: name, bundleID: bundleID, icon: icon,
            source: detectSource(url, bundleID: bundleID, brewNames: brewNames), color: color,
            dateAdded: meta.added ?? creationDate(url), lastUsed: meta.lastUsed, useCount: meta.useCount
        )
    }

    // MARK: - Источник установки

    private static func detectSource(_ url: URL, bundleID: String?, brewNames: Set<String>) -> AppSource {
        let real = url.resolvingSymlinksInPath().path
        if real.hasPrefix("/System/") { return .system }
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt").path) {
            return .appStore
        }
        if real.contains("/Caskroom/") || brewNames.contains(url.lastPathComponent) { return .brew }
        if bundleID?.hasPrefix("com.apple.") == true { return .system }
        return .manual
    }

    /// Имена .app, установленных через brew cask: Caskroom/<token>/<версия>/<Имя>.app
    private static func brewAppNames() -> Set<String> {
        let fm = FileManager.default
        var names = Set<String>()
        for room in caskrooms {
            for token in (try? fm.contentsOfDirectory(atPath: room)) ?? [] {
                let tokenDir = "\(room)/\(token)"
                for version in (try? fm.contentsOfDirectory(atPath: tokenDir)) ?? [] where !version.hasPrefix(".") {
                    for entry in (try? fm.contentsOfDirectory(atPath: "\(tokenDir)/\(version)")) ?? []
                    where entry.hasSuffix(".app") {
                        names.insert(entry)
                    }
                }
            }
        }
        return names
    }

    // MARK: - Метаданные

    private static func spotlightMeta(_ url: URL) -> (added: Date?, lastUsed: Date?, useCount: Int) {
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else { return (nil, nil, 0) }
        func attr(_ key: String) -> Any? { MDItemCopyAttribute(item, key as CFString) }
        return (attr("kMDItemDateAdded") as? Date,
                attr("kMDItemLastUsedDate") as? Date,
                (attr("kMDItemUseCount") as? NSNumber)?.intValue ?? 0)
    }

    private static func creationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    private static func modificationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static func directorySize(_ url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in walker {
            guard let v = try? file.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    /// Иконка растеризуется заранее в 2x (256 px для иконки до 128 pt), чтобы UI не тратил время на отрисовку.
    private static func renderIcon(_ url: URL) -> (NSImage, IconColor) {
        let source = NSWorkspace.shared.icon(forFile: url.path)
        var rect = CGRect(x: 0, y: 0, width: 256, height: 256)
        guard let cg = source.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return (source, .dark) }
        return (NSImage(cgImage: cg, size: NSSize(width: 128, height: 128)), IconColor.dominant(of: cg))
    }
}
