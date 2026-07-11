//
//  MomentumComponents.swift
//  StepOne
//

import SwiftUI

struct GlassPressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct DiagonalStripes: View {
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

struct PhysicalActivityIconView: View {
    let color: Color
    var body: some View {
        Canvas { context, size in
            let s = size.width / 24
            let style = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)

            var head = Path()
            head.addEllipse(in: CGRect(x: (12 - 1.9) * s, y: (4.4 - 1.9) * s, width: 3.8 * s, height: 3.8 * s))
            context.stroke(head, with: .color(color), style: style)

            var limbs = Path()
            limbs.move(to: CGPoint(x: 12 * s, y: 6.8 * s))
            limbs.addLine(to: CGPoint(x: 12 * s, y: 11.8 * s))
            limbs.move(to: CGPoint(x: 12 * s, y: 11.8 * s))
            limbs.addLine(to: CGPoint(x: 8.8 * s, y: 18.2 * s))
            limbs.move(to: CGPoint(x: 12 * s, y: 11.8 * s))
            limbs.addLine(to: CGPoint(x: 15.2 * s, y: 18.2 * s))
            limbs.move(to: CGPoint(x: 8.3 * s, y: 9.8 * s))
            limbs.addLine(to: CGPoint(x: 12 * s, y: 8.3 * s))
            limbs.addLine(to: CGPoint(x: 15.7 * s, y: 9.8 * s))
            context.stroke(limbs, with: .color(color), style: style)
        }
    }
}

struct HouseworkIconView: View {
    let color: Color
    var body: some View {
        Canvas { context, size in
            let s = size.width / 24
            let style = StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)

            var broom = Path()
            broom.move(to: CGPoint(x: 14.5 * s, y: 3 * s))
            broom.addLine(to: CGPoint(x: 10.5 * s, y: 11.2 * s))
            broom.move(to: CGPoint(x: 10.5 * s, y: 11.2 * s))
            broom.addLine(to: CGPoint(x: 6.8 * s, y: 17.8 * s))
            broom.move(to: CGPoint(x: 10.5 * s, y: 11.2 * s))
            broom.addLine(to: CGPoint(x: 9.2 * s, y: 18.5 * s))
            broom.move(to: CGPoint(x: 10.5 * s, y: 11.2 * s))
            broom.addLine(to: CGPoint(x: 12.1 * s, y: 18.2 * s))
            broom.move(to: CGPoint(x: 15.2 * s, y: 16.2 * s))
            broom.addLine(to: CGPoint(x: 20.2 * s, y: 16.2 * s))
            broom.addLine(to: CGPoint(x: 20.2 * s, y: 19.8 * s))
            broom.addLine(to: CGPoint(x: 14 * s, y: 19.8 * s))
            broom.closeSubpath()
            context.stroke(broom, with: .color(color), style: style)
        }
    }
}

struct CreativityIconView: View {
    let color: Color
    var body: some View {
        Canvas { context, size in
            let s = size.width / 24
            var blob = Path()
            blob.addEllipse(in: CGRect(x: 3 * s, y: 3 * s, width: 18 * s, height: 18 * s))
            context.stroke(blob, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineJoin: .round))

            for (cx, cy) in [(8.0, 10.2), (11.8, 7.6), (15.8, 10.2)] {
                let r: CGFloat = 1.25 * s
                let rect = CGRect(x: cx * s - r, y: cy * s - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}

struct MomentumCardView: View {
    let action: MomentumAction
    let size: CGSize
    let theme: MomentumTheme
    let hueColor: Color
    let hueOpacity: Double

    private var liteColor: Color { Color(hue: action.hue / 360, saturation: theme.stripeSaturation, brightness: theme.stripeLiteBrightness) }
    private var darkColor: Color { Color(hue: action.hue / 360, saturation: theme.stripeSaturation + 0.04, brightness: theme.stripeDarkBrightness) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text(action.title)
                    .font(.system(size: 27, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .lineSpacing(3)
                    .padding(.trailing, 62)
                    .fixedSize(horizontal: false, vertical: true)

                Text(action.desc)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                DiagonalStripes(lite: liteColor, dark: darkColor)
                    .frame(height: size.height * 0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        Text(action.label)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(theme.chipText)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(theme.chipBg, in: RoundedRectangle(cornerRadius: 8))
                    )
            }
            .padding(EdgeInsets(top: 24, leading: 24, bottom: 22, trailing: 24))

            Text("+\(action.meters) m")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(theme.chipBg, in: Capsule())
                .padding(.top, 20)
                .padding(.trailing, 20)
        }
        .frame(width: size.width, height: size.height)
        .background(.ultraThinMaterial)
        .background(theme.cardTint)
        .overlay(hueColor.opacity(hueOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .strokeBorder(theme.cardBorder, lineWidth: 0.5)
        )
        .shadow(color: theme.cardShadowColor.opacity(0.16), radius: 30, x: 0, y: 24)
        .shadow(color: theme.cardShadowColor.opacity(0.08), radius: 7, x: 0, y: 4)
    }
}

struct RewardPopView: View {
    let text: String
    let color: Color

    @State private var offsetY: CGFloat = 26
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0

    var body: some View {
        Text(text)
            .font(.system(size: 38, weight: .heavy))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.35), radius: 14, x: 0, y: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: offsetY)
            .onAppear {
                withAnimation(.linear(duration: 1.1)) {
                    offsetY = -64
                    scale = 1.06
                }
                withAnimation(.easeIn(duration: 0.2)) {
                    opacity = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.79) {
                    withAnimation(.easeOut(duration: 0.31)) {
                        opacity = 0
                    }
                }
            }
    }
}
