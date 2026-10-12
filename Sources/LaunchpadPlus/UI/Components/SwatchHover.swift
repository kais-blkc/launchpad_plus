import SwiftUI

/// Кружок цвета слегка «подпрыгивает» при наведении.
struct SwatchHover: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? 1.18 : 1)
            .brightness(hovering ? 0.08 : 0)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.14), value: hovering)
    }
}
