import SwiftUI

/// Общий стиль выпадающих панелей (сортировка, настройки).
extension View {
    /// Строка выпадающего списка: шрифт, отступы и hover-подсветка.
    func dropdownRow() -> some View {
        self.font(.system(size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .hoverBackground(RoundedRectangle(cornerRadius: 7), base: 0, hover: 0.18, scale: 1)
    }

    /// Тёмная полупрозрачная панель со скруглением, рамкой и тенью.
    func dropdownPanel(anchor: UnitPoint) -> some View {
        self.padding(6)
            .frame(minWidth: 230)
            .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.55)))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: anchor)))
    }
}
