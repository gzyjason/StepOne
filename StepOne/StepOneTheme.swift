//
//  StepOneTheme.swift
//  StepOne
//
//  Light and night palettes, transcribed from the design's theme() table.
//

import SwiftUI

extension Color {
    /// sRGB from 0-255 components, matching the design's `rgba()` values.
    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.init(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }

    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            r: Double((hex >> 16) & 0xFF),
            g: Double((hex >> 8) & 0xFF),
            b: Double(hex & 0xFF),
            a: opacity
        )
    }

    /// The design specifies its washes and card art in OKLCH. Converting
    /// properly keeps the hues identical rather than eyeballing them.
    init(oklch l: Double, _ c: Double, _ hDegrees: Double, opacity: Double = 1) {
        let h = hDegrees * .pi / 180
        let a = c * cos(h)
        let bb = c * sin(h)

        let l_ = l + 0.3963377774 * a + 0.2158037573 * bb
        let m_ = l - 0.1055613458 * a - 0.0638541728 * bb
        let s_ = l - 0.0894841775 * a - 1.2914855480 * bb

        let lC = l_ * l_ * l_
        let mC = m_ * m_ * m_
        let sC = s_ * s_ * s_

        let rLin = 4.0767416621 * lC - 3.3077115913 * mC + 0.2309699292 * sC
        let gLin = -1.2684380046 * lC + 2.6097574011 * mC - 0.3413193965 * sC
        let bLin = -0.0041960863 * lC - 0.7034186147 * mC + 1.7076147010 * sC

        func gamma(_ v: Double) -> Double {
            let clamped = min(max(v, 0), 1)
            return clamped <= 0.0031308
                ? 12.92 * clamped
                : 1.055 * pow(clamped, 1 / 2.4) - 0.055
        }

        self.init(.sRGB, red: gamma(rLin), green: gamma(gLin), blue: gamma(bLin), opacity: opacity)
    }
}

struct StepOneTheme {
    let isNight: Bool

    let screenBg: Color
    let textPrimary: Color
    let textSecondary: Color
    let icon: Color
    let hint: Color
    let chevron: Color

    let glassTint: Color
    let glassBorder: Color
    let cardTint: Color
    let cardBorder: Color
    let chipBg: Color
    let chipText: Color
    let toastTint: Color
    let toastBorder: Color
    let menuTint: Color

    let sepThin: Color
    let sepThick: Color
    let tabHighlight: Color
    let segBg: Color
    let segThumb: Color

    let accent: Color
    let accentCheck: Color
    let destructive: Color

    let blob1: Color
    let blob2: Color
    let blob3: Color

    let shadow: Color
    let cardShadow: Color

    static let light = StepOneTheme(
        isNight: false,
        screenBg: Color(hex: 0xFAF6EE),
        textPrimary: Color(hex: 0x241F16),
        textSecondary: Color(r: 64, g: 56, b: 40, a: 0.62),
        icon: Color(hex: 0x404040),
        hint: Color(r: 80, g: 70, b: 52, a: 0.5),
        chevron: Color(r: 60, g: 60, b: 67, a: 0.3),
        glassTint: Color(r: 255, g: 255, b: 255, a: 0.5),
        glassBorder: Color(r: 0, g: 0, b: 0, a: 0.06),
        cardTint: Color(r: 255, g: 255, b: 255, a: 0.52),
        cardBorder: Color(r: 255, g: 255, b: 255, a: 0.6),
        chipBg: Color(r: 255, g: 255, b: 255, a: 0.6),
        chipText: Color(r: 50, g: 45, b: 35, a: 0.6),
        toastTint: Color(r: 255, g: 255, b: 255, a: 0.72),
        toastBorder: Color(r: 0, g: 0, b: 0, a: 0.05),
        menuTint: Color(r: 252, g: 249, b: 242, a: 0.72),
        sepThin: Color(r: 0, g: 0, b: 0, a: 0.09),
        sepThick: Color(r: 0, g: 0, b: 0, a: 0.05),
        tabHighlight: Color(r: 255, g: 255, b: 255, a: 0.8),
        segBg: Color(r: 120, g: 120, b: 128, a: 0.16),
        segThumb: Color(hex: 0xFFFFFF),
        accent: Color(hex: 0x2F6FE0),
        accentCheck: Color(hex: 0x1E9E4C),
        destructive: Color(hex: 0xD93B30),
        blob1: Color(oklch: 0.9, 0.06, 85, opacity: 0.55),
        blob2: Color(oklch: 0.9, 0.06, 55, opacity: 0.5),
        blob3: Color(oklch: 0.9, 0.05, 250, opacity: 0.4),
        shadow: Color(r: 0, g: 0, b: 0, a: 0.07),
        cardShadow: Color(oklch: 0.4, 0.04, 80)
    )

    static let night = StepOneTheme(
        isNight: true,
        screenBg: Color(hex: 0x101A2E),
        textPrimary: Color(hex: 0xF2EFE6),
        textSecondary: Color(r: 230, g: 225, b: 210, a: 0.62),
        icon: Color(r: 255, g: 255, b: 255, a: 0.78),
        hint: Color(r: 215, g: 210, b: 195, a: 0.42),
        chevron: Color(r: 235, g: 235, b: 245, a: 0.35),
        glassTint: Color(r: 120, g: 120, b: 128, a: 0.28),
        glassBorder: Color(r: 255, g: 255, b: 255, a: 0.15),
        cardTint: Color(r: 90, g: 105, b: 140, a: 0.22),
        cardBorder: Color(r: 255, g: 255, b: 255, a: 0.16),
        chipBg: Color(r: 15, g: 22, b: 38, a: 0.55),
        chipText: Color(r: 230, g: 225, b: 210, a: 0.7),
        toastTint: Color(r: 60, g: 72, b: 100, a: 0.55),
        toastBorder: Color(r: 255, g: 255, b: 255, a: 0.14),
        menuTint: Color(r: 52, g: 60, b: 82, a: 0.6),
        sepThin: Color(r: 255, g: 255, b: 255, a: 0.12),
        sepThick: Color(r: 0, g: 0, b: 0, a: 0.22),
        tabHighlight: Color(r: 255, g: 255, b: 255, a: 0.16),
        segBg: Color(r: 120, g: 120, b: 128, a: 0.28),
        segThumb: Color(hex: 0x636366),
        accent: Color(hex: 0x5A8DEF),
        accentCheck: Color(hex: 0x4CD964),
        destructive: Color(hex: 0xFF6961),
        blob1: Color(oklch: 0.45, 0.09, 280, opacity: 0.5),
        blob2: Color(oklch: 0.42, 0.08, 220, opacity: 0.45),
        blob3: Color(oklch: 0.4, 0.07, 320, opacity: 0.4),
        shadow: Color(r: 0, g: 0, b: 0, a: 0.35),
        cardShadow: Color(r: 0, g: 0, b: 0, a: 1)
    )

    static func of(night: Bool) -> StepOneTheme { night ? .night : .light }

    /// iOS green used for the settings switches in both themes.
    static let switchOn = Color(hex: 0x34C759)
    static let switchOff = Color(r: 120, g: 120, b: 128, a: 0.32)

    var cardShadowStrong: Color { isNight ? cardShadow.opacity(0.45) : cardShadow.opacity(0.16) }
    var cardShadowSoft: Color { isNight ? cardShadow.opacity(0.3) : cardShadow.opacity(0.08) }
}

private struct StepOneThemeKey: EnvironmentKey {
    static let defaultValue = StepOneTheme.light
}

extension EnvironmentValues {
    var stepTheme: StepOneTheme {
        get { self[StepOneThemeKey.self] }
        set { self[StepOneThemeKey.self] = newValue }
    }
}
