//
//  ContentView.swift
//  StepOne
//
//  Created by Jason Gao on 7/9/26.
//

import SwiftUI

private struct MomentumAction {
    let title: String
    let desc: String
    let label: String
    let hue: Double
}

private let momentumActions: [MomentumAction] = [
    MomentumAction(title: "Take a short walk", desc: "Walk for 5 minutes around your current location. No destination needed.", label: "photo · short walk outside", hue: 130),
    MomentumAction(title: "Drink a glass of water", desc: "Fill a glass and sip it slowly, start to finish.", label: "photo · glass of water", hue: 230),
    MomentumAction(title: "Make your bed", desc: "Straighten the sheets and set the pillow back in place.", label: "photo · freshly made bed", hue: 60),
    MomentumAction(title: "Open a window", desc: "Let fresh air in for two minutes and just breathe.", label: "photo · open window", hue: 190),
    MomentumAction(title: "Stretch your arms", desc: "Reach up as high as you can and hold for three slow breaths.", label: "photo · morning stretch", hue: 300),
    MomentumAction(title: "Text a friend", desc: "Send one short message to someone you like.", label: "photo · texting a friend", hue: 20),
]

private enum DragAxis {
    case horizontal, vertical
}

private struct GlassPressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ContentView: View {
    var userName: String = "Alex"
    var showHints: Bool = true

    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var dragAxis: DragAxis?
    @State private var isDragging = false
    @State private var isAnimating = false
    @State private var isFading = false
    @State private var doneCount = 0
    @State private var toast: String?
    @State private var toastWorkItem: DispatchWorkItem?

    private let slot: CGFloat = 340
    private let cardSize = CGSize(width: 312, height: 540)

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
        return "Good \(part)"
    }

    private func mod(_ i: Int) -> Int {
        let n = momentumActions.count
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
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color(red: 0xFA / 255, green: 0xF6 / 255, blue: 0xEE / 255))
        .ignoresSafeArea()
    }

    // MARK: - Ambient background

    private func ambientBlobs(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.98, green: 0.92, blue: 0.74).opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 190))
                .frame(width: 380, height: 380)
                .position(x: 90, y: 70)

            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.83, green: 0.93, blue: 0.85).opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 210))
                .frame(width: 420, height: 420)
                .position(x: size.width - 60, y: size.height * 0.3 + 210)

            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.85, green: 0.88, blue: 0.97).opacity(0.4), .clear], center: .center, startRadius: 0, endRadius: 200))
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
                .foregroundColor(Color(red: 0x24 / 255, green: 0x1F / 255, blue: 0x16 / 255))
                .frame(minHeight: 27, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: {}) {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(Color.white.opacity(0.5))
                    Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                    VStack(spacing: 3.7) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1.1)
                                .fill(Color(white: 0.25))
                                .frame(width: 18, height: 2.2)
                        }
                    }
                }
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.07), radius: 3, x: 0, y: 1)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
            }
            .buttonStyle(GlassPressStyle(scale: 0.94))
        }
        .padding(.horizontal, 20)
        .padding(.top, 74)
        .padding(.bottom, 6)
    }

    // MARK: - Card stage

    private var cardStage: some View {
        ZStack {
            ForEach([-1, 0, 1], id: \.self) { p in
                cardView(for: p)
            }

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(Color(red: 0x24 / 255, green: 0x1F / 255, blue: 0x16 / 255))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .background(Color.white.opacity(0.72), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .padding(.bottom, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(20)
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func cardView(for p: Int) -> some View {
        let action = momentumActions[mod(index + p)]
        let u = CGFloat(p) + drag.width / slot
        let tx = u * slot
        let ty: CGFloat = p == 0 ? drag.height : 0
        let rotation = u * 7
        let scale = 1 - min(abs(u), 1.4) * 0.06
        let opacity: Double = (isFading && p == 0) ? 0 : 1
        let z: Double = p == 0 ? 3 : 1

        let card = MomentumCardView(action: action, size: cardSize)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(x: tx, y: ty)
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
                } else if axis == .vertical, abs(dy) > 110 {
                    complete(dy < 0 ? -1 : 1)
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        drag = .zero
                    }
                }
            }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 14) {
            if showHints {
                Text("swipe up when it's done \u{00B7} swipe sideways for another")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0x50 / 255, green: 0x46 / 255, blue: 0x34 / 255).opacity(0.5))
            }
            Button(action: {}) {
                Text("Your Journey")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(red: 0x24 / 255, green: 0x1F / 255, blue: 0x16 / 255))
                    .padding(.horizontal, 32)
                    .frame(height: 52)
                    .background(.ultraThinMaterial, in: Capsule())
                    .background(Color.white.opacity(0.55), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.07), radius: 3, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(GlassPressStyle(scale: 0.96))
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 48)
    }

    // MARK: - Gesture actions

    private var cardAnimation: Animation {
        .timingCurve(0.32, 0.72, 0.28, 1, duration: 0.46)
    }

    private func slide(_ dir: Int) {
        guard !isAnimating, !isDragging else { return }
        isAnimating = true
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

    private func complete(_ dir: Int) {
        guard !isAnimating, !isDragging else { return }
        isAnimating = true
        isFading = true
        withAnimation(cardAnimation) {
            drag = CGSize(width: 0, height: CGFloat(dir) * 950)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
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
            let message = doneCount == 1 ? "Nice \u{2014} 1 small step done today" : "Nice \u{2014} \(doneCount) small steps done today"
            withAnimation(.easeOut(duration: 0.3)) {
                toast = message
            }
            let work = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.3)) {
                    toast = nil
                }
            }
            toastWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
        }
    }
}

// MARK: - Card

private struct MomentumCardView: View {
    let action: MomentumAction
    let size: CGSize

    private var liteColor: Color { Color(hue: action.hue / 360, saturation: 0.14, brightness: 0.95) }
    private var darkColor: Color { Color(hue: action.hue / 360, saturation: 0.18, brightness: 0.90) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(action.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Color(red: 0x22 / 255, green: 0x1D / 255, blue: 0x13 / 255))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(action.desc)
                .font(.system(size: 14.5))
                .foregroundColor(Color(red: 64 / 255, green: 56 / 255, blue: 40 / 255).opacity(0.62))
                .lineSpacing(3)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            DiagonalStripes(lite: liteColor, dark: darkColor)
                .frame(height: size.height * 0.52)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    Text(action.label)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(Color(red: 50 / 255, green: 45 / 255, blue: 35 / 255).opacity(0.6))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                )
        }
        .padding(EdgeInsets(top: 28, leading: 26, bottom: 26, trailing: 26))
        .frame(width: size.width, height: size.height)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color(red: 0.35, green: 0.3, blue: 0.2).opacity(0.16), radius: 30, x: 0, y: 24)
        .shadow(color: Color(red: 0.35, green: 0.3, blue: 0.2).opacity(0.08), radius: 7, x: 0, y: 4)
    }
}

private struct DiagonalStripes: View {
    let lite: Color
    let dark: Color
    private let bandWidth: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(dark))

            let diagonal = (size.width + size.height) * 1.5
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: .degrees(45))
            context.translateBy(x: -diagonal / 2, y: -diagonal / 2)

            var x: CGFloat = 0
            while x < diagonal {
                context.fill(Path(CGRect(x: x, y: 0, width: bandWidth, height: diagonal)), with: .color(lite))
                x += bandWidth * 2
            }
        }
    }
}

#Preview {
    ContentView()
}
