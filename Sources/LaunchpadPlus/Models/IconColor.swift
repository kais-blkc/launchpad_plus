import AppKit
import SwiftUI

/// Доминирующий цвет иконки, разбитый на крупные корзины для фильтра.
enum IconColor: Int, CaseIterable, Hashable {
    case red, orange, yellow, green, cyan, blue, purple, pink, dark, light

    @MainActor var title: String { L("color.\(self)") }

    var swatch: Color {
        switch self {
        case .red: Color(hue: 0.00, saturation: 0.75, brightness: 0.95)
        case .orange: Color(hue: 0.08, saturation: 0.80, brightness: 1.0)
        case .yellow: Color(hue: 0.15, saturation: 0.80, brightness: 1.0)
        case .green: Color(hue: 0.33, saturation: 0.70, brightness: 0.85)
        case .cyan: Color(hue: 0.50, saturation: 0.65, brightness: 0.95)
        case .blue: Color(hue: 0.62, saturation: 0.75, brightness: 1.0)
        case .purple: Color(hue: 0.77, saturation: 0.60, brightness: 0.90)
        case .pink: Color(hue: 0.90, saturation: 0.55, brightness: 1.0)
        case .dark: Color(white: 0.12)
        case .light: Color(white: 0.96)
        }
    }

    /// Определяет преобладающий цвет по уменьшенной копии иконки.
    /// Насыщенные пиксели весят больше нейтральных, иначе белый фон «перебивал» бы цветной значок.
    static func dominant(of image: CGImage) -> IconColor {
        let side = 32
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = bytes.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return .dark }

        var score = [Double](repeating: 0, count: IconColor.allCases.count)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let a = Double(bytes[i + 3]) / 255
            guard a > 0.5 else { continue }
            let r = Double(bytes[i]) / 255 / a, g = Double(bytes[i + 1]) / 255 / a, b = Double(bytes[i + 2]) / 255 / a
            let mx = max(r, g, b), mn = min(r, g, b)
            let sat = mx == 0 ? 0 : (mx - mn) / mx

            if sat < 0.18 || mx < 0.15 {
                score[(mx > 0.6 ? IconColor.light : IconColor.dark).rawValue] += 0.2
                continue
            }
            var h: Double
            let d = mx - mn
            if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h /= 6
            if h < 0 { h += 1 }
            score[bucket(hue: h).rawValue] += sat * a
        }
        let best = score.indices.max { score[$0] < score[$1] } ?? IconColor.dark.rawValue
        return IconColor(rawValue: best) ?? .dark
    }

    private static func bucket(hue h: Double) -> IconColor {
        switch h {
        case ..<0.04, 0.95...: .red
        case ..<0.11: .orange
        case ..<0.20: .yellow
        case ..<0.45: .green
        case ..<0.55: .cyan
        case ..<0.72: .blue
        case ..<0.83: .purple
        default: .pink
        }
    }
}
