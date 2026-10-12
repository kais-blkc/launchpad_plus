import SwiftUI

/// Полупрозрачная подложка, которая светлеет и чуть увеличивается при наведении.
private struct HoverBackground<S: InsettableShape>: ViewModifier {
    let shape: S
    let base: Double
    let hover: Double
    var scale: CGFloat = 1.04

    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(.white.opacity(hovering ? hover : base), in: shape)
            .scaleEffect(hovering ? scale : 1)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.14), value: hovering)
            .animation(.easeOut(duration: 0.14), value: base)
    }
}

extension View {
    func hoverBackground<S: InsettableShape>(_ shape: S, base: Double, hover: Double,
                                             scale: CGFloat = 1.04) -> some View {
        modifier(HoverBackground(shape: shape, base: base, hover: hover, scale: scale))
    }
}
