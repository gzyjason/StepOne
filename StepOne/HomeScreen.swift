//
//  HomeScreen.swift
//  StepOne
//
//  The card stage: greeting, Your Journey, swipeable trips, category tabs
//  and the overflow menu.
//

import SwiftUI

private enum DragAxis { case horizontal, vertical }

struct HomeScreen: View {
    @Bindable var store: StepOneStore

    @State private var dragAxis: DragAxis?

    private var theme: StepOneTheme { store.theme }

    var body: some View {
        ZStack {
            AmbientBackground(theme: theme, spots: AmbientBackground.Blob.home)

            VStack(spacing: 0) {
                header
                cardStage.frame(maxHeight: .infinity)
                footer
            }

            menuLayer
        }
        .background(theme.screenBg)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Text(store.greetingLine)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.textPrimary)
                .frame(minHeight: 27, alignment: .leading)

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeOut(duration: 0.22)) { store.menuOpen.toggle() }
            } label: {
                VStack(spacing: 3.7) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.1)
                            .fill(theme.icon)
                            .frame(width: 18, height: 2.2)
                    }
                }
                .frame(width: 44, height: 44)
                .glassCapsule(theme)
            }
            .buttonStyle(PressStyle(scale: 0.94))
        }
        .padding(.horizontal, 20)
        .padding(.top, 74)
        .padding(.bottom, 4)
    }

    // MARK: Card stage

    private var cardStage: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let cardY = geo.size.height / 2 + 24

            ZStack {
                Button { store.screen = .journey } label: {
                    Text(store.S["journey"])
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, 30)
                        .frame(height: 48)
                        .glassCapsule(theme)
                }
                .buttonStyle(PressStyle())
                .position(x: centerX, y: max(40, cardY - TripCardView.size.height / 2 - 62))

                ForEach([-1, 0, 1], id: \.self) { slot in
                    card(slot: slot, centerX: centerX, centerY: cardY)
                }

                if let toast = store.toast {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 9)
                            .background(.ultraThinMaterial, in: Capsule())
                            .background(theme.toastTint, in: Capsule())
                            .overlay(Capsule().strokeBorder(theme.toastBorder, lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                            .padding(.bottom, 4)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
                }

                if let reward = store.reward {
                    RewardPop(text: reward, color: theme.accentCheck)
                        .position(x: centerX, y: geo.size.height * 0.4)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    @ViewBuilder
    private func card(slot: Int, centerX: CGFloat, centerY: CGFloat) -> some View {
        let trips = store.trips
        if !trips.isEmpty {
            let trip = trips[store.wrapped(store.index + slot)]
            let u = CGFloat(slot) + store.drag.width / store.slot
            let offsetX = u * store.slot
            let offsetY: CGFloat = slot == 0 ? store.drag.height : 0
            let scale = 1 - min(abs(u), 1.4) * 0.06
            let isTop = slot == 0

            TripCardView(
                title: trip.title,
                desc: trip.desc,
                emoji: trip.emoji,
                metersLabel: "+" + store.unit.format(trip.meters),
                theme: theme,
                tint: store.drag.height < 0
                    ? Color(r: 48, g: 209, b: 88)
                    : Color(r: 255, g: 69, b: 58),
                tintOpacity: isTop ? min(abs(store.drag.height) / 280, 0.32) : 0
            )
            .scaleEffect(scale)
            .rotationEffect(.degrees(u * 7))
            .position(x: centerX + offsetX, y: centerY + offsetY)
            .opacity(store.isFading && isTop ? 0 : 1)
            .zIndex(isTop ? 3 : 1)
            .modifier(CardInteraction(store: store, slot: slot, dragAxis: $dragAxis))
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Text(store.S["hint"])
                .font(.system(size: 12))
                .foregroundStyle(theme.hint)
                .opacity(store.hintSeen ? 0 : 1)
                .animation(.easeInOut(duration: 0.6), value: store.hintSeen)

            HStack(spacing: 0) {
                ForEach(store.chosen, id: \.self) { id in
                    let active = store.category == id
                    Button { store.setCategory(id) } label: {
                        ZStack {
                            Capsule()
                                .fill(theme.tabHighlight)
                                .opacity(active ? 1 : 0)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 5)
                            VStack(spacing: 3) {
                                CategoryIcon(category: id, color: theme.icon, size: 23)
                                Text(store.S.categoryName(id))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 108)
                        .opacity(active ? 1 : 0.55)
                    }
                    .buttonStyle(PressStyle(scale: 0.95))
                    .animation(.easeOut(duration: 0.25), value: active)
                }
            }
            .frame(height: 64)
            .glassCapsule(theme)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 44)
    }

    // MARK: Menu

    private var menuLayer: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(store.menuOpen ? 0.16 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(store.menuOpen)
                .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { store.menuOpen = false } }

            VStack(spacing: 0) {
                menuRow(store.S["menuTrips"], icon: "square.grid.2x2") { store.screen = .tripTypes }
                Separator(theme: theme)
                menuRow(store.S["menuDiscarded"], icon: "trash") { store.screen = .discarded }
                Rectangle().fill(theme.sepThick).frame(height: 6)
                menuRow(store.S["settings"], icon: "gearshape") { store.screen = .settings }
            }
            .frame(width: 254)
            .background(.ultraThinMaterial)
            .background(theme.menuTint)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(theme.glassBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.28), radius: 25, x: 0, y: 18)
            .scaleEffect(store.menuOpen ? 1 : 0.55, anchor: .topTrailing)
            .offset(y: store.menuOpen ? 0 : -8)
            .opacity(store.menuOpen ? 1 : 0)
            .allowsHitTesting(store.menuOpen)
            .padding(.top, 126)
            .padding(.trailing, 18)
            .animation(.spring(response: 0.34, dampingFraction: 0.62), value: store.menuOpen)
        }
    }

    private func menuRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            store.menuOpen = false
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.icon)
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
    }
}

// MARK: - Card gesture

/// Axis-locked drag: sideways changes trip, up completes, down discards.
private struct CardInteraction: ViewModifier {
    @Bindable var store: StepOneStore
    let slot: Int
    @Binding var dragAxis: DragAxis?

    func body(content: Content) -> some View {
        if slot == 0 {
            content.gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !store.isAnimating else { return }
                        if dragAxis == nil {
                            let dx = value.translation.width
                            let dy = value.translation.height
                            guard hypot(dx, dy) >= 6 else { return }
                            dragAxis = abs(dx) >= abs(dy) ? .horizontal : .vertical
                            store.isDragging = true
                        }
                        switch dragAxis {
                        case .horizontal: store.drag = CGSize(width: value.translation.width, height: 0)
                        case .vertical: store.drag = CGSize(width: 0, height: value.translation.height)
                        case .none: break
                        }
                    }
                    .onEnded { _ in
                        guard !store.isAnimating else { return }
                        let axis = dragAxis
                        dragAxis = nil
                        store.isDragging = false
                        let dx = store.drag.width
                        let dy = store.drag.height

                        if axis == .horizontal, abs(dx) > 90 {
                            store.slide(dx < 0 ? 1 : -1)
                        } else if axis == .vertical, dy < -110 {
                            store.completeTrip()
                        } else if axis == .vertical, dy > 110 {
                            store.discardTrip()
                        } else {
                            withAnimation(.easeOut(duration: 0.3)) { store.drag = .zero }
                        }
                    }
            )
        } else {
            content.onTapGesture { store.slide(slot) }
        }
    }
}

// MARK: - Reward pop

struct RewardPop: View {
    let text: String
    let color: Color

    @State private var offsetY: CGFloat = 26
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0

    var body: some View {
        Text(text)
            .font(.system(size: 38, weight: .heavy))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.35), radius: 14, x: 0, y: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: offsetY)
            .onAppear {
                withAnimation(.linear(duration: 1.1)) {
                    offsetY = -64
                    scale = 1.06
                }
                withAnimation(.easeIn(duration: 0.2)) { opacity = 1 }
                withAnimation(.easeOut(duration: 0.31).delay(0.79)) { opacity = 0 }
            }
    }
}
