import SwiftUI

struct RootView: View {
    @ObservedObject var store: AppStore
    var onBackgroundClick: () -> Void
    var onLaunch: () -> Void

    @ObservedObject private var l10n = Localizer.shared
    @FocusState private var searchFocused: Bool
    @Namespace private var segmentNS
    @State private var sortOpen = false
    @State private var settingsOpen = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private let spacing: CGFloat = 24
    private let sidePadding: CGFloat = 80
    private let fadeHeight: CGFloat = 36

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { if sortOpen || settingsOpen { closePopups() } else { onBackgroundClick() } }

            VStack(spacing: 18) {
                searchField
                controls.zIndex(1)
                grid.overlay {
                    if sortOpen || settingsOpen {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { closePopups() }
                    }
                }
            }
            .padding(.top, 48)
        }
        .overlay(alignment: .topTrailing) { settingsButton.padding(.top, 20).padding(.trailing, 24) }
        .onAppear { searchFocused = true }
    }

    // MARK: - Сетка

    private var cellWidth: CGFloat { store.iconSize * 1.55 }

    private var grid: some View {
        GeometryReader { geo in
            let inner = geo.size.width - sidePadding * 2
            let count = max(1, Int((inner + spacing) / (cellWidth + spacing)))
            let columns = Array(repeating: GridItem(.fixed(cellWidth), spacing: spacing), count: count)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 32) {
                        ForEach(store.filtered) { app in
                            AppCell(app: app, iconSize: store.iconSize, caption: store.caption(for: app), lang: l10n.code,
                                    selected: store.selectedID == app.id,
                                    onLaunch: { store.launch(app); onLaunch() },
                                    onReveal: {
                                        onLaunch()   // сначала прячем оверлей, иначе он закроет окно Finder
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { store.reveal(app) }
                                    },
                                    onCopyPath: { store.copyPath(app) },
                                    onTrash: { store.moveToTrash(app) })
                                .equatable()
                                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        }
                    }
                    .animation(.snappy(duration: 0.28), value: store.filtered)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .scrollIndicators(.hidden)
                .onChange(of: store.selectedID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) }
                }
            }
            .onAppear { store.columns = count }
            .onChange(of: count) { _, new in store.columns = new }
        }
        // плавное затухание у верхней и нижней границы, а не резкий срез
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: fadeHeight)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: fadeHeight)
            }
        )
    }

    // MARK: - Панель управления

    private var hasActiveFilters: Bool { store.filter != nil || store.colorFilter != nil }

    private var controls: some View {
        VStack(spacing: 6) {
            // Если все группы не помещаются в строку — переносим сортировку и размер на вторую строку.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 18) {
                    sourceGroup
                    divider
                    colorGroup
                    divider
                    sortGroup
                    divider
                    sizeGroup
                }
                VStack(spacing: 12) {
                    HStack(alignment: .bottom, spacing: 18) {
                        sourceGroup
                        divider
                        colorGroup
                    }
                    HStack(alignment: .bottom, spacing: 18) {
                        sortGroup
                        divider
                        sizeGroup
                    }
                }
            }

            summary
        }
    }

    /// Подпись над группой элементов — чтобы сразу было понятно, что это за переключатель.
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased(with: l10n.locale))
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
            content()
        }
    }

    private var sourceGroup: some View { group(L("group.source")) { sourceSegments } }
    private var colorGroup: some View { group(L("group.color")) { colorSwatches } }
    private var sortGroup: some View { group(L("group.sort")) { sortControl } }
    private var sizeGroup: some View { group(L("group.size")) { iconSizeSlider } }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 30)
    }

    /// «Показано N из M» и кнопка сброса, когда включён хотя бы один фильтр.
    private var summary: some View {
        HStack(spacing: 10) {
            Text(L("summary.shown", store.filtered.count, store.apps.count))
                .foregroundStyle(.white.opacity(0.55))
            if hasActiveFilters {
                Button { store.resetFilters() } label: {
                    Label(L("summary.reset"), systemImage: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .transition(.opacity)
            }
        }
        .font(.system(size: 12))
        .animation(.easeOut(duration: 0.15), value: hasActiveFilters)
    }

    // Источник: сегментированный переключатель с «ползунком», который плавно переезжает.

    private var sourceSegments: some View {
        HStack(spacing: 2) {
            segment(L("filter.all"), source: nil)
            ForEach(AppSource.allCases, id: \.self) { segment($0.title, source: $0) }
        }
        .padding(3)
        .background(.white.opacity(0.08), in: Capsule())
    }

    private func segment(_ title: String, source: SourceFilter) -> some View {
        let selected = store.filter == source
        return Button {
            withAnimation(.snappy(duration: 0.25)) { store.filter = source }
        } label: {
            HStack(spacing: 5) {
                Text(title)
                Text("\(store.count(for: source))").foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: 13, weight: selected ? .semibold : .regular))
            .foregroundStyle(.white.opacity(selected ? 1 : 0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .hoverBackground(Capsule(), base: 0, hover: selected ? 0 : 0.12, scale: 1)
            .background {
                if selected {
                    Capsule().fill(.white.opacity(0.28)).matchedGeometryEffect(id: "segment", in: segmentNS)
                }
            }
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help(source?.hint ?? L("filter.all.hint"))
    }

    // Сортировка: выбор критерия + отдельная кнопка направления.

    private var sortControl: some View {
        HStack(spacing: 2) {
            // Свой выпадающий список: системные меню (Menu/NSMenu) в этом окне не нажимаются и не дают hover.
            Button { withAnimation(.easeOut(duration: 0.15)) { sortOpen.toggle() } } label: {
                HStack(spacing: 7) {
                    Text(store.sort.title)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .hoverBackground(Capsule(), base: 0, hover: 0.12, scale: 1)
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .overlay(alignment: .topLeading) {
                if sortOpen { sortDropdown.fixedSize().offset(y: 36) }
            }

            Button { store.reversed.toggle() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(store.reversed ? 0 : 180))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 28, height: 26)
                    .hoverBackground(Capsule(), base: 0, hover: 0.12, scale: 1)
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .help(store.reversed ? L("sort.order.reversed") : L("sort.order.normal"))
            .animation(.snappy(duration: 0.25), value: store.reversed)
        }
        .padding(3)
        .background(.white.opacity(0.08), in: Capsule())
    }

    private var sortDropdown: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    store.sort = option
                    withAnimation(.easeOut(duration: 0.15)) { sortOpen = false }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(store.sort == option ? 1 : 0)
                            .frame(width: 14)
                        Text(option.title)
                        Spacer(minLength: 0)
                    }
                    .dropdownRow()
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .dropdownPanel(anchor: .topLeading)
    }

    private func closePopups() {
        withAnimation(.easeOut(duration: 0.15)) { sortOpen = false; settingsOpen = false }
    }

    // MARK: - Настройки (шестерёнка)

    private var settingsButton: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { sortOpen = false; settingsOpen.toggle() }; launchAtLogin = LaunchAtLogin.isEnabled } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .hoverBackground(Circle(), base: 0.08, hover: 0.2)
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help(L("settings.help"))
        .overlay(alignment: .topTrailing) {
            if settingsOpen { settingsDropdown.fixedSize().offset(y: 42) }
        }
    }

    private var settingsDropdown: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L("settings.language").uppercased(with: l10n.locale))
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

            languageRow(title: L("settings.system"), choice: Localizer.systemChoice)
            ForEach(Localizer.languages) { languageRow(title: $0.nativeName, choice: $0.code) }

            Rectangle().fill(.white.opacity(0.12)).frame(height: 1).padding(.vertical, 4)

            Button {
                LaunchAtLogin.set(!launchAtLogin)
                launchAtLogin = LaunchAtLogin.isEnabled
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(launchAtLogin ? 1 : 0)
                        .frame(width: 14)
                    Text(L("settings.launchAtLogin"))
                    Spacer(minLength: 0)
                }
                .dropdownRow()
            }
            .buttonStyle(.plain)
            .pointerCursor()

            Button { NSApp.terminate(nil) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "power").font(.system(size: 11, weight: .semibold)).frame(width: 14)
                    Text(L("settings.quit"))
                    Spacer(minLength: 0)
                }
                .dropdownRow()
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
        .dropdownPanel(anchor: .topTrailing)
    }

    private func languageRow(title: String, choice: String) -> some View {
        Button {
            l10n.setChoice(choice)
            closePopups()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(l10n.choice == choice ? 1 : 0)
                    .frame(width: 14)
                Text(title)
                Spacer(minLength: 0)
            }
            .dropdownRow()
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private var colorSwatches: some View {
        HStack(spacing: 6) {
            ForEach(IconColor.allCases, id: \.self) { color in
                let selected = store.colorFilter == color
                Button { store.colorFilter = selected ? nil : color } label: {
                    Circle()
                        .fill(color.swatch)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.white.opacity(selected ? 1 : 0.25), lineWidth: selected ? 2 : 1))
                        .scaleEffect(selected ? 1.2 : 1)
                }
                .buttonStyle(.plain)
                .modifier(SwatchHover())
                .pointerCursor()
                .help(color.title)
            }
        }
        .padding(.vertical, 4)
        .animation(.easeOut(duration: 0.15), value: store.colorFilter)
    }

    private var iconSizeSlider: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.3x3").font(.system(size: 11))
            Slider(value: $store.iconSize, in: 56...128)
                .frame(width: 90)
                .pointerCursor()
            Image(systemName: "square.grid.2x2").font(.system(size: 13))
        }
        .foregroundStyle(.white.opacity(0.7))
        .frame(height: 26)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            TextField(L("search.placeholder"), text: $store.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
        }
        .font(.system(size: 15))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(width: 260)
        .hoverBackground(RoundedRectangle(cornerRadius: 8), base: 0.15, hover: 0.24, scale: 1.02)
    }
}
