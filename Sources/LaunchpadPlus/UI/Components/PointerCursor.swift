import SwiftUI

/// Курсор-«рука» над кликабельным элементом.
/// На macOS 15+ — штатный `.pointerStyle(.link)`, на 14 — ручной push/pop курсора.
private struct PointerCursor: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(.link)
        } else {
            content.modifier(LegacyPointerCursor())
        }
    }
}

private struct LegacyPointerCursor: ViewModifier {
    @State private var inside = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                guard hovering != inside else { return }
                inside = hovering
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            // ячейка могла исчезнуть из-под курсора (фильтр, поиск) — не оставляем курсор «залипшим»
            .onDisappear {
                if inside { inside = false; NSCursor.pop() }
            }
    }
}

extension View {
    func pointerCursor() -> some View { modifier(PointerCursor()) }
}
