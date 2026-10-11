import AppKit

struct AppItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleID: String?
    let icon: NSImage
    let source: AppSource
    let color: IconColor
    let dateAdded: Date?
    let lastUsed: Date?
    let useCount: Int
    var size: Int64 = 0

    var id: String { url.path }

    static func == (l: AppItem, r: AppItem) -> Bool {
        l.url == r.url && l.name == r.name && l.source == r.source && l.size == r.size
            && l.lastUsed == r.lastUsed && l.useCount == r.useCount && l.dateAdded == r.dateAdded
    }
    func hash(into h: inout Hasher) { h.combine(url) }
}
