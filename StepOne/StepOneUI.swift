//
//  StepOneUI.swift
//  StepOne
//
//  Shared surfaces and controls: liquid glass, category icons, trip card,
//  settings rows and the alert sheet.
//

import SwiftUI

/// Locked direction of a card drag. Shared by the home deck and the
/// onboarding demo deck, which handle swipes the same way.
enum DragAxis { case horizontal, vertical }

// MARK: - Press feedback

struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Row highlight used by the settings lists and menu.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.gray.opacity(0.15) : .clear)
    }
}

// MARK: - Glass

extension View {
    /// The design's liquid-glass recipe: blur, tint, hairline border and a
    /// two-layer drop shadow.
    func glass<S: InsettableShape>(_ theme: StepOneTheme, shape: S, tint: Color? = nil, shadow: Bool = true) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)
            .background(tint ?? theme.glassTint, in: shape)
            .overlay(shape.strokeBorder(theme.glassBorder, lineWidth: 0.5))
            .compositingGroup()
            .shadow(color: shadow ? theme.shadow : .clear, radius: 3, x: 0, y: 1)
            .shadow(color: shadow ? theme.shadow : .clear, radius: 10, x: 0, y: 3)
    }

    func glassCard(_ theme: StepOneTheme, radius: CGFloat = 26) -> some View {
        glass(theme, shape: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func glassCapsule(_ theme: StepOneTheme) -> some View {
        glass(theme, shape: Capsule())
    }
}

/// Ambient colour washes behind the glass. `spots` are unit-space centres.
struct AmbientBackground: View {
    let theme: StepOneTheme
    var spots: [Blob] = Blob.home

    struct Blob {
        let color: KeyPath<StepOneTheme, Color>
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat

        static let home: [Blob] = [
            Blob(color: \.blob1, x: 0.0, y: 0.0, size: 380),
            Blob(color: \.blob2, x: 1.0, y: 0.42, size: 420),
            Blob(color: \.blob3, x: 0.1, y: 1.0, size: 400),
        ]
        static let topLeft: [Blob] = [Blob(color: \.blob1, x: 0.0, y: 0.0, size: 380)]
        static let topRight: [Blob] = [Blob(color: \.blob3, x: 1.0, y: 0.0, size: 380)]
        static let bottomLeft: [Blob] = [Blob(color: \.blob1, x: 0.0, y: 1.0, size: 380)]
        static let bottomRight: [Blob] = [Blob(color: \.blob2, x: 1.0, y: 1.0, size: 380)]
        static let journey: [Blob] = [
            Blob(color: \.blob1, x: 0.0, y: 0.0, size: 380),
            Blob(color: \.blob2, x: 1.0, y: 0.45, size: 360),
        ]
        static let settings: [Blob] = [
            Blob(color: \.blob1, x: 0.0, y: 0.0, size: 380),
            Blob(color: \.blob2, x: 1.0, y: 1.0, size: 400),
        ]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(spots.enumerated()), id: \.offset) { _, blob in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [theme[keyPath: blob.color], .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: blob.size / 2
                            )
                        )
                        .frame(width: blob.size, height: blob.size)
                        .position(x: geo.size.width * blob.x, y: geo.size.height * blob.y)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Category icons

/// Redrawn from the design's `catIcon` SVG paths on a 24×24 grid.
struct CategoryIcon: View {
    let category: String
    let color: Color
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 24
            let stroke = StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            switch category {
            case "creativity":
                var blob = Path()
                blob.addEllipse(in: CGRect(x: 3 * s, y: 3 * s, width: 18 * s, height: 18 * s))
                context.stroke(blob, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineJoin: .round))
                for (cx, cy) in [(8.0, 10.2), (11.8, 7.6), (15.8, 10.2)] {
                    let r = 1.25 * s
                    context.fill(
                        Path(ellipseIn: CGRect(x: cx * s - r, y: cy * s - r, width: r * 2, height: r * 2)),
                        with: .color(color)
                    )
                }

            case "physical":
                var head = Path()
                head.addEllipse(in: CGRect(x: (12 - 1.9) * s, y: (4.4 - 1.9) * s, width: 3.8 * s, height: 3.8 * s))
                context.stroke(head, with: .color(color), style: stroke)
                var body = Path()
                body.move(to: pt(12, 6.8)); body.addLine(to: pt(12, 11.8))
                body.move(to: pt(12, 11.8)); body.addLine(to: pt(8.8, 18.2))
                body.move(to: pt(12, 11.8)); body.addLine(to: pt(15.2, 18.2))
                body.move(to: pt(8.3, 9.8)); body.addLine(to: pt(12, 8.3)); body.addLine(to: pt(15.7, 9.8))
                context.stroke(body, with: .color(color), style: stroke)

            case "housework":
                var broom = Path()
                broom.move(to: pt(14.5, 3)); broom.addLine(to: pt(10.5, 11.2))
                broom.move(to: pt(10.5, 11.2)); broom.addLine(to: pt(6.8, 17.8))
                broom.move(to: pt(10.5, 11.2)); broom.addLine(to: pt(9.2, 18.5))
                broom.move(to: pt(10.5, 11.2)); broom.addLine(to: pt(12.1, 18.2))
                broom.move(to: pt(15.2, 16.2)); broom.addLine(to: pt(20.2, 16.2))
                broom.addLine(to: pt(20.2, 19.8)); broom.addLine(to: pt(14, 19.8))
                broom.closeSubpath()
                context.stroke(broom, with: .color(color), style: stroke)

            case "hygiene":
                var drop = Path()
                drop.move(to: pt(12, 3.5))
                drop.addCurve(to: pt(17, 13), control1: pt(15, 7.3), control2: pt(17, 10.3))
                drop.addArc(center: pt(12, 13), radius: 5 * s, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                drop.addCurve(to: pt(12, 3.5), control1: pt(7, 10.3), control2: pt(9, 7.3))
                context.stroke(drop, with: .color(color), style: stroke)

            case "study":
                var book = Path()
                book.move(to: pt(12, 6.5))
                book.addCurve(to: pt(4.5, 5), control1: pt(10, 5), control2: pt(7.3, 4.5))
                book.addLine(to: pt(4.5, 17))
                book.addCurve(to: pt(12, 18.5), control1: pt(7.3, 16.5), control2: pt(10, 17))
                book.addCurve(to: pt(19.5, 17), control1: pt(14, 17), control2: pt(16.7, 16.5))
                book.addLine(to: pt(19.5, 5))
                book.addCurve(to: pt(12, 6.5), control1: pt(16.7, 4.5), control2: pt(14, 5))
                book.move(to: pt(12, 6.5)); book.addLine(to: pt(12, 18.5))
                context.stroke(book, with: .color(color), style: stroke)

            case "hobby":
                var star = Path()
                star.move(to: pt(12, 3.5)); star.addLine(to: pt(14.5, 8.9))
                star.addLine(to: pt(20.4, 9.5)); star.addLine(to: pt(16, 13.5))
                star.addLine(to: pt(17.2, 19.3)); star.addLine(to: pt(12, 16.6))
                star.addLine(to: pt(6.8, 19.3)); star.addLine(to: pt(8, 13.5))
                star.addLine(to: pt(3.6, 9.5)); star.addLine(to: pt(9.5, 8.9))
                star.closeSubpath()
                context.stroke(star, with: .color(color), style: stroke)

            case "social":
                var bubble = Path()
                bubble.move(to: pt(4.5, 5.5)); bubble.addLine(to: pt(19.5, 5.5))
                bubble.addLine(to: pt(19.5, 15.5)); bubble.addLine(to: pt(10.5, 15.5))
                bubble.addLine(to: pt(6.5, 19)); bubble.addLine(to: pt(6.5, 15.5))
                bubble.addLine(to: pt(4.5, 15.5)); bubble.closeSubpath()
                context.stroke(bubble, with: .color(color), style: stroke)
                for cx in [9.0, 12.0, 15.0] {
                    let r = 0.9 * s
                    context.fill(
                        Path(ellipseIn: CGRect(x: cx * s - r, y: 10.5 * s - r, width: r * 2, height: r * 2)),
                        with: .color(color)
                    )
                }

            default:
                break
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Trip card

struct TripCardView: View {
    let title: String
    let desc: String
    let emoji: String
    let metersLabel: String
    let theme: StepOneTheme
    /// Green when swiping up to complete, red when swiping down to discard.
    var tint: Color = .clear
    var tintOpacity: Double = 0

    static let size = CGSize(width: 312, height: 408)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(2)
                    .padding(.trailing, 62)
                    .fixedSize(horizontal: false, vertical: true)

                Text(desc)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)

                // Takes every point left under the copy so the emoji lands in
                // the middle of that block rather than hugging its bottom.
                Text(emoji)
                    .font(.system(size: 112))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 12)
            }
            .padding(EdgeInsets(top: 24, leading: 24, bottom: 22, trailing: 24))

            Text(metersLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(theme.chipBg, in: Capsule())
                .padding(.top, 20)
                .padding(.trailing, 20)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(.ultraThinMaterial)
        .background(theme.cardTint)
        .overlay(tint.opacity(tintOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .strokeBorder(theme.cardBorder, lineWidth: 0.5)
        )
        .compositingGroup()
        .shadow(color: theme.cardShadowStrong, radius: 30, x: 0, y: 24)
        .shadow(color: theme.cardShadowSoft, radius: 7, x: 0, y: 4)
    }
}

// MARK: - Settings building blocks

struct ScreenHeader: View {
    let backLabel: String
    let title: String
    var subtitle: String?
    let theme: StepOneTheme
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 1) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text(backLabel)
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(theme.textPrimary)
                .padding(.leading, 6)
                .padding(.trailing, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(PressStyle(scale: 1))

            Text(title)
                .font(.system(size: 33, weight: .heavy))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, subtitle == nil ? 18 : 6)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13.5))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 64)
        .padding(.horizontal, 10)
    }
}

struct SectionLabel: View {
    let text: String
    let theme: StepOneTheme

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12.5, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(theme.textSecondary)
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A settings row: icon, title, optional detail, and a trailing accessory.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var systemIcon: String?
    var detail: String?
    let theme: StepOneTheme
    var height: CGFloat = 52
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(theme.icon)
                    .frame(width: 19, height: 19)
            }
            Text(title)
                .font(.system(size: 15.5))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let detail {
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(height: height)
        .contentShape(Rectangle())
    }
}

struct Chevron: View {
    let theme: StepOneTheme
    var size: CGFloat = 16
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: size * 0.75, weight: .bold))
            .foregroundStyle(theme.chevron)
    }
}

struct Separator: View {
    let theme: StepOneTheme
    var inset: CGFloat = 16
    var body: some View {
        Rectangle()
            .fill(theme.sepThin)
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

struct StepSwitch: View {
    let isOn: Bool
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? StepOneTheme.switchOn : StepOneTheme.switchOff)
                .frame(width: 42, height: 25)
            Circle()
                .fill(.white)
                .frame(width: 21, height: 21)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                .padding(2)
        }
        .animation(.interpolatingSpring(stiffness: 250, damping: 20), value: isOn)
    }
}

/// Filled accent button with an optional inline spinner.
struct PrimaryButton: View {
    let title: String
    let theme: StepOneTheme
    var busy = false
    var enabled = true
    var height: CGFloat = 54
    var radius: CGFloat = 18
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled && !busy { action() } }) {
            ZStack {
                Text(title)
                    .font(.system(size: height >= 54 ? 17 : 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(busy ? 0 : 1)
                if busy { Spinner(color: .white, size: 20) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .opacity(enabled ? 1 : 0.4)
            .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }
}

struct Spinner: View {
    let color: Color
    var size: CGFloat = 20
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.25)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}

/// Glass text field matching the design's rounded input.
struct GlassField: View {
    let placeholder: String
    @Binding var text: String
    let theme: StepOneTheme
    var secure = false
    var keyboard: UIKeyboardType = .default
    var height: CGFloat = 52
    var tracking: CGFloat = 0

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                    .autocorrectionDisabled(keyboard == .emailAddress)
            }
        }
        .font(.system(size: 16))
        .kerning(tracking)
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 18)
        .frame(height: height)
        .glass(theme, shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Inline validation message under a field. The row is laid out whether or not
/// there is a message, so an error appearing never pushes the rest of the form
/// around. Pass an empty string for the quiet state.
struct FieldError: View {
    let message: String
    let theme: StepOneTheme
    /// Matches the horizontal inset of the field it sits under.
    var inset: CGFloat = 6

    /// One line of the message font, rounded up. Longer copy still wraps and
    /// grows the row — the reserve only covers the single-line case, which is
    /// every message at every stock screen width.
    static let reservedHeight: CGFloat = 16

    var body: some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(theme.destructive)
            .padding(.horizontal, inset)
            .frame(maxWidth: .infinity, minHeight: Self.reservedHeight, alignment: .topLeading)
    }
}

// MARK: - Alert

/// The design's centred glass alert with two footer actions.
struct StepAlert: View {
    let title: String
    let message: String
    let cancelTitle: String
    let confirmTitle: String
    let theme: StepOneTheme
    var confirmDestructive = true
    var confirmBusy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Rectangle().fill(theme.sepThin).frame(height: 0.5)

            HStack(spacing: 0) {
                Button(action: onCancel) {
                    Text(cancelTitle)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(RowPressStyle())

                Rectangle().fill(theme.sepThin).frame(width: 0.5)

                Button(action: onConfirm) {
                    ZStack {
                        Text(confirmTitle)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(confirmDestructive ? theme.destructive : theme.textPrimary)
                            .opacity(confirmBusy ? 0 : 1)
                        if confirmBusy { Spinner(color: theme.destructive, size: 16) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(RowPressStyle())
            }
            .frame(height: 46)
        }
        .frame(width: 282)
        .background(.ultraThinMaterial)
        .background(theme.menuTint)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(theme.glassBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 22)
    }
}

/// Wraps an alert in its dimmed backdrop with the design's pop-in transform.
struct AlertOverlay<Content: View>: View {
    let isPresented: Bool
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(isPresented ? 0.28 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(isPresented)
                .onTapGesture(perform: onDismiss)

            content()
                .scaleEffect(isPresented ? 1 : 1.12)
                .opacity(isPresented ? 1 : 0)
                .allowsHitTesting(isPresented)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isPresented)
    }
}
