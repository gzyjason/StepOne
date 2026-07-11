//
//  ContentView.swift
//  StepOne
//
//  Created by Jason Gao on 7/9/26.
//

import SwiftUI

private enum DragAxis {
    case horizontal, vertical
}

struct ContentView: View {
    var userName: String = "Alex"
    var showHints: Bool = true

    @State private var category: MomentumCategory = .physical
    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var dragAxis: DragAxis?
    @State private var isDragging = false
    @State private var isAnimating = false
    @State private var isFading = false
    @State private var doneCount = 0
    @State private var totalMeters = 0
    @State private var toast: String?
    @State private var toastWorkItem: DispatchWorkItem?
    @State private var reward: String?
    @State private var rewardWorkItem: DispatchWorkItem?
    @State private var menuOpen = false
    @State private var nightOverride: Bool?
    @State private var hintSeen = false

    private let slot: CGFloat = 340
    private let cardSize = CGSize(width: 312, height: 408)

    private var isNight: Bool { nightOverride ?? false }
    private var theme: MomentumTheme { isNight ? .dark : .light }

    private var rewardColor: Color {
        isNight ? Color(red: 76 / 255, green: 217 / 255, blue: 100 / 255) : Color(red: 30 / 255, green: 158 / 255, blue: 76 / 255)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
        return "Good \(part)"
    }

    private func mod(_ i: Int) -> Int {
        let n = momentumActionsByCategory[category]!.count
        return ((i % n) + n) % n
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ambientBlobs(in: geo.size)

                VStack(spacing: 0) {
                    header
                    cardStage
                        .frame(maxHeight: .infinity)
                    footer
                }

                dimOverlay

                menuPanel
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 126)
                    .padding(.trailing, 18)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(theme.screenBg)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: isNight)
        .environment(\.colorScheme, isNight ? .dark : .light)
    }

    // MARK: - Ambient background

    private func ambientBlobs(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [theme.blob1, .clear], center: .center, startRadius: 0, endRadius: 190))
                .frame(width: 380, height: 380)
                .position(x: 90, y: 70)

            Circle()
                .fill(RadialGradient(colors: [theme.blob2, .clear], center: .center, startRadius: 0, endRadius: 210))
                .frame(width: 420, height: 420)
                .position(x: size.width - 60, y: size.height * 0.3 + 210)

            Circle()
                .fill(RadialGradient(colors: [theme.blob3, .clear], center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 400, height: 400)
                .position(x: 130, y: size.height - 50)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(greeting), \(userName)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.textPrimary)
                .frame(minHeight: 27, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: { withAnimation(.easeOut(duration: 0.22)) { menuOpen.toggle() } }) {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(theme.glassTint)
                    Circle().strokeBorder(theme.glassBorder, lineWidth: 0.5)
                    VStack(spacing: 3.7) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1.1)
                                .fill(theme.icon)
                                .frame(width: 18, height: 2.2)
                        }
                    }
                }
                .frame(width: 44, height: 44)
                .shadow(color: theme.shadowColor, radius: 3, x: 0, y: 1)
                .shadow(color: theme.shadowColor, radius: 10, x: 0, y: 3)
            }
            .buttonStyle(GlassPressStyle(scale: 0.94))
        }
        .padding(.horizontal, 20)
        .padding(.top, 74)
        .padding(.bottom, 4)
    }

    // MARK: - Card stage

    private var cardStage: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cardCenterY = geo.size.height / 2 + 24

            ZStack {
                journeyButton
                    .position(x: cx, y: geo.size.height / 2 - 266 + 24)

                ForEach([-1, 0, 1], id: \.self) { p in
                    cardView(for: p, centerX: cx, centerY: cardCenterY)
                }

                if let toast {
                    VStack {
                        Spacer()
                        toastView(toast)
                            .padding(.bottom, 4)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(20)
                    .allowsHitTesting(false)
                }

                if let reward {
                    RewardPopView(text: reward, color: rewardColor)
                        .position(x: cx, y: geo.size.height * 0.4)
                        .zIndex(22)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var journeyButton: some View {
        Button(action: {}) {
            Text("Your Journey")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 30)
                .frame(height: 48)
                .background(.ultraThinMaterial, in: Capsule())
                .background(theme.glassTint, in: Capsule())
                .overlay(Capsule().strokeBorder(theme.glassBorder, lineWidth: 0.5))
                .shadow(color: theme.shadowColor, radius: 3, x: 0, y: 1)
                .shadow(color: theme.shadowColor, radius: 10, x: 0, y: 3)
        }
        .buttonStyle(GlassPressStyle(scale: 0.96))
    }

    @ViewBuilder
    private func cardView(for p: Int, centerX: CGFloat, centerY: CGFloat) -> some View {
        let list = momentumActionsByCategory[category]!
        let action = list[mod(index + p)]
        let u = CGFloat(p) + drag.width / slot
        let tx = u * slot
        let ty: CGFloat = p == 0 ? drag.height : 0
        let rotation = u * 7
        let scale = 1 - min(abs(u), 1.4) * 0.06
        let opacity: Double = (isFading && p == 0) ? 0 : 1
        let z: Double = p == 0 ? 3 : 1
        let hueOpacity: Double = p == 0 ? min(abs(drag.height) / 280, 0.32) : 0
        let hueColor: Color = drag.height < 0
            ? Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
            : Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)

        let card = MomentumCardView(action: action, size: cardSize, theme: theme, hueColor: hueColor, hueOpacity: hueOpacity)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .position(x: centerX + tx, y: centerY + ty)
            .opacity(opacity)
            .zIndex(z)

        if p == 0 {
            card.gesture(topDragGesture)
        } else {
            card.onTapGesture { slide(p) }
        }
    }

    private var topDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isAnimating else { return }
                if dragAxis == nil {
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard hypot(dx, dy) >= 6 else { return }
                    dragAxis = abs(dx) >= abs(dy) ? .horizontal : .vertical
                    isDragging = true
                }
                switch dragAxis {
                case .horizontal:
                    drag = CGSize(width: value.translation.width, height: 0)
                case .vertical:
                    drag = CGSize(width: 0, height: value.translation.height)
                case .none:
                    break
                }
            }
            .onEnded { _ in
                guard !isAnimating else { return }
                let axis = dragAxis
                dragAxis = nil
                isDragging = false
                let dx = drag.width
                let dy = drag.height
                if axis == .horizontal, abs(dx) > 90 {
                    slide(dx < 0 ? 1 : -1)
                } else if axis == .vertical, dy < -110 {
                    complete()
                } else if axis == .vertical, dy > 110 {
                    discard()
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        drag = .zero
                    }
                }
            }
    }

    private func toastView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 17)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
            .background(theme.toastTint, in: Capsule())
            .overlay(Capsule().strokeBorder(theme.toastBorder, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Footer (hint + tab bar)

    private var footer: some View {
        VStack(spacing: 10) {
            if showHints {
                Text("swipe up to complete \u{00B7} down to discard \u{00B7} sideways for another")
                    .font(.system(size: 12))
                    .foregroundColor(theme.hint)
                    .opacity(hintSeen ? 0 : 1)
                    .animation(.easeInOut(duration: 0.6), value: hintSeen)
            }
            tabBar
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 44)
    }

    private var tabBar: some View {
        ZStack {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(theme.glassTint)
            Capsule().strokeBorder(theme.glassBorder, lineWidth: 0.5)

            HStack(spacing: 0) {
                tabItem(.creativity, label: "Creativity") {
                    CreativityIconView(color: theme.icon)
                }
                tabItem(.physical, label: "Physical Activity") {
                    PhysicalActivityIconView(color: theme.icon)
                }
                tabItem(.housework, label: "Housework") {
                    HouseworkIconView(color: theme.icon)
                }
            }
        }
        .frame(height: 64)
        .frame(maxWidth: 344)
        .shadow(color: theme.shadowColor, radius: 3, x: 0, y: 1)
        .shadow(color: theme.shadowColor, radius: 10, x: 0, y: 3)
    }

    @ViewBuilder
    private func tabItem<Icon: View>(_ cat: MomentumCategory, label: String, @ViewBuilder icon: () -> Icon) -> some View {
        let active = category == cat
        Button(action: { setCategory(cat) }) {
            ZStack {
                Capsule()
                    .fill(theme.tabHighlight)
                    .opacity(active ? 1 : 0)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 5)
                VStack(spacing: 2) {
                    icon().frame(width: 23, height: 23)
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .opacity(active ? 1 : 0.55)
        }
        .buttonStyle(GlassPressStyle(scale: 0.95))
        .animation(.easeOut(duration: 0.25), value: active)
    }

    // MARK: - Menu

    private var dimOverlay: some View {
        Color.black.opacity(menuOpen ? 0.16 : 0)
            .allowsHitTesting(menuOpen)
            .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { menuOpen = false } }
            .ignoresSafeArea()
    }

    private var menuPanel: some View {
        VStack(spacing: 0) {
            Button(action: toggleNight) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 15))
                            .foregroundColor(theme.icon)
                        Text("Night Mode")
                            .font(.system(size: 15))
                            .foregroundColor(theme.textPrimary)
                    }
                    Spacer()
                    nightSwitch
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
            }
            .buttonStyle(.plain)

            Rectangle().fill(theme.sepThick).frame(height: 6)

            menuRow(icon: "square.grid.2x2", label: "Action Types")
            Rectangle().fill(theme.sepThin).frame(height: 0.5).padding(.leading, 16)
            menuRow(icon: "trash", label: "Discarded Actions")

            Rectangle().fill(theme.sepThick).frame(height: 6)

            menuRow(icon: "gearshape", label: "Settings")
        }
        .background(.ultraThinMaterial)
        .background(theme.menuTint)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(theme.glassBorder, lineWidth: 0.5)
        )
        .frame(width: 254)
        .shadow(color: .black.opacity(0.28), radius: 25, x: 0, y: 9)
        .shadow(color: .black.opacity(0.14), radius: 7, x: 0, y: 2)
        .scaleEffect(menuOpen ? 1 : 0.55, anchor: .topTrailing)
        .offset(y: menuOpen ? 0 : -8)
        .opacity(menuOpen ? 1 : 0)
        .allowsHitTesting(menuOpen)
        .animation(.interpolatingSpring(stiffness: 260, damping: 22), value: menuOpen)
    }

    private func menuRow(icon: String, label: String) -> some View {
        Button(action: { menuOpen = false }) {
            HStack {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(theme.icon)
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
        }
        .buttonStyle(.plain)
    }

    private var nightSwitch: some View {
        ZStack(alignment: isNight ? .trailing : .leading) {
            Capsule()
                .fill(isNight ? Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255) : Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.32))
                .frame(width: 42, height: 25)
            Circle()
                .fill(Color.white)
                .frame(width: 21, height: 21)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                .padding(2)
        }
        .animation(.interpolatingSpring(stiffness: 250, damping: 20), value: isNight)
    }

    private func toggleNight() {
        nightOverride = !isNight
    }

    // MARK: - Gesture actions

    private var cardAnimation: Animation {
        .timingCurve(0.32, 0.72, 0.28, 1, duration: 0.46)
    }

    private func setCategory(_ cat: MomentumCategory) {
        guard cat != category else { return }
        category = cat
        index = 0
        drag = .zero
        isAnimating = false
        isFading = false
    }

    private func slide(_ dir: Int) {
        guard !isAnimating, !isDragging else { return }
        isAnimating = true
        hintSeen = true
        withAnimation(cardAnimation) {
            drag = CGSize(width: -CGFloat(dir) * slot, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.47) {
            index = mod(index + dir)
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                drag = .zero
            }
            isAnimating = false
        }
    }

    private func complete() {
        guard !isAnimating, !isDragging else { return }
        let m = momentumActionsByCategory[category]![mod(index)].meters
        isAnimating = true
        isFading = true
        hintSeen = true
        reward = "+\(m) m"

        withAnimation(cardAnimation) {
            drag = CGSize(width: 0, height: -950)
        }

        rewardWorkItem?.cancel()
        let rWork = DispatchWorkItem { reward = nil }
        rewardWorkItem = rWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15, execute: rWork)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            totalMeters += m
            doneCount += 1
            index = mod(index + 1)
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                drag = .zero
                isFading = false
            }
            isAnimating = false

            toastWorkItem?.cancel()
            let message = "You\u{2019}ve traveled \(totalMeters) m today"
            withAnimation(.easeOut(duration: 0.3)) { toast = message }
            let work = DispatchWorkItem { withAnimation(.easeOut(duration: 0.3)) { toast = nil } }
            toastWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
        }
    }

    private func discard() {
        guard !isAnimating, !isDragging else { return }
        isAnimating = true
        isFading = true
        hintSeen = true

        withAnimation(cardAnimation) {
            drag = CGSize(width: 0, height: 950)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            index = mod(index + 1)
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                drag = .zero
                isFading = false
            }
            isAnimating = false

            toastWorkItem?.cancel()
            withAnimation(.easeOut(duration: 0.3)) { toast = "Discarded \u{2014} saved under Discarded Actions" }
            let work = DispatchWorkItem { withAnimation(.easeOut(duration: 0.3)) { toast = nil } }
            toastWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
        }
    }
}

#Preview {
    ContentView()
}
