import SwiftUI

/// Одна ячейка сетки: иконка, название, подпись и контекстное меню.
struct AppCell: View {
    let app: AppItem
    let iconSize: Double
    let caption: String?
    let lang: String   // участвует в сравнении: при смене языка ячейка должна перерисоваться
    let selected: Bool
    var onLaunch: () -> Void
    var onReveal: () -> Void
    var onCopyPath: () -> Void
    var onTrash: () -> Void

    @State private var hovering = false

    var body: some View {
        let highlighted = hovering || selected
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: iconSize, height: iconSize)
            Text(app.name)
                .font(.system(size: iconSize > 100 ? 14 : 13))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            if let caption {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background {
            // тень и подсветка существуют только у выделенной ячейки — в покое сетка рисуется дешевле
            if highlighted {
                RoundedRectangle(cornerRadius: 14).fill(.white.opacity(selected ? 0.18 : 0.1))
            }
        }
        .scaleEffect(hovering ? 1.07 : 1)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .animation(.easeOut(duration: 0.14), value: selected)
        .onTapGesture(perform: onLaunch)
        .pointerCursor()
        .contextMenu {
            Button(L("cell.open"), action: onLaunch)
            Button(L("cell.reveal"), action: onReveal)
            Button(L("cell.copyPath"), action: onCopyPath)
            Divider()
            Button(L("cell.trash"), role: .destructive, action: onTrash)
                .disabled(app.source == .system)
        }
    }
}

extension AppCell: Equatable {
    static func == (l: AppCell, r: AppCell) -> Bool {
        l.app == r.app && l.iconSize == r.iconSize && l.caption == r.caption && l.lang == r.lang && l.selected == r.selected
    }
}
