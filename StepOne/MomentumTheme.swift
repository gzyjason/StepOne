//
//  MomentumTheme.swift
//  StepOne
//

import SwiftUI

struct MomentumTheme {
    let isNight: Bool
    let screenBg: Color
    let textPrimary: Color
    let textSecondary: Color
    let icon: Color
    let hint: Color
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
    let blob1: Color
    let blob2: Color
    let blob3: Color
    let stripeSaturation: Double
    let stripeLiteBrightness: Double
    let stripeDarkBrightness: Double
    let shadowColor: Color
    let cardShadowColor: Color

    static let light = MomentumTheme(
        isNight: false,
        screenBg: Color(red: 0xFA / 255, green: 0xF6 / 255, blue: 0xEE / 255),
        textPrimary: Color(red: 0x24 / 255, green: 0x1F / 255, blue: 0x16 / 255),
        textSecondary: Color(red: 64 / 255, green: 56 / 255, blue: 40 / 255).opacity(0.62),
        icon: Color(white: 0.25),
        hint: Color(red: 0x50 / 255, green: 0x46 / 255, blue: 0x34 / 255).opacity(0.5),
        glassTint: Color.white.opacity(0.5),
        glassBorder: Color.black.opacity(0.06),
        cardTint: Color.white.opacity(0.52),
        cardBorder: Color.white.opacity(0.6),
        chipBg: Color.white.opacity(0.6),
        chipText: Color(red: 50 / 255, green: 45 / 255, blue: 35 / 255).opacity(0.6),
        toastTint: Color.white.opacity(0.72),
        toastBorder: Color.black.opacity(0.05),
        menuTint: Color(red: 252 / 255, green: 249 / 255, blue: 242 / 255).opacity(0.72),
        sepThin: Color.black.opacity(0.09),
        sepThick: Color.black.opacity(0.05),
        tabHighlight: Color.white.opacity(0.8),
        blob1: Color(red: 0.98, green: 0.92, blue: 0.74).opacity(0.55),
        blob2: Color(red: 0.83, green: 0.93, blue: 0.85).opacity(0.45),
        blob3: Color(red: 0.85, green: 0.88, blue: 0.97).opacity(0.4),
        stripeSaturation: 0.16,
        stripeLiteBrightness: 0.95,
        stripeDarkBrightness: 0.90,
        shadowColor: Color.black.opacity(0.07),
        cardShadowColor: Color(red: 0.35, green: 0.3, blue: 0.2)
    )

    static let dark = MomentumTheme(
        isNight: true,
        screenBg: Color(red: 0x10 / 255, green: 0x1A / 255, blue: 0x2E / 255),
        textPrimary: Color(red: 0xF2 / 255, green: 0xEF / 255, blue: 0xE6 / 255),
        textSecondary: Color(red: 230 / 255, green: 225 / 255, blue: 210 / 255).opacity(0.62),
        icon: Color.white.opacity(0.78),
        hint: Color(red: 215 / 255, green: 210 / 255, blue: 195 / 255).opacity(0.42),
        glassTint: Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.28),
        glassBorder: Color.white.opacity(0.15),
        cardTint: Color(red: 90 / 255, green: 105 / 255, blue: 140 / 255).opacity(0.22),
        cardBorder: Color.white.opacity(0.16),
        chipBg: Color(red: 15 / 255, green: 22 / 255, blue: 38 / 255).opacity(0.55),
        chipText: Color(red: 230 / 255, green: 225 / 255, blue: 210 / 255).opacity(0.7),
        toastTint: Color(red: 60 / 255, green: 72 / 255, blue: 100 / 255).opacity(0.55),
        toastBorder: Color.white.opacity(0.14),
        menuTint: Color(red: 52 / 255, green: 60 / 255, blue: 82 / 255).opacity(0.6),
        sepThin: Color.white.opacity(0.12),
        sepThick: Color.black.opacity(0.22),
        tabHighlight: Color.white.opacity(0.16),
        blob1: Color(hue: 280 / 360, saturation: 0.4, brightness: 0.55).opacity(0.5),
        blob2: Color(hue: 220 / 360, saturation: 0.35, brightness: 0.5).opacity(0.45),
        blob3: Color(hue: 320 / 360, saturation: 0.3, brightness: 0.5).opacity(0.4),
        stripeSaturation: 0.24,
        stripeLiteBrightness: 0.5,
        stripeDarkBrightness: 0.42,
        shadowColor: Color.black.opacity(0.3),
        cardShadowColor: Color.black
    )
}

enum MomentumCategory: String, CaseIterable {
    case creativity, physical, housework

    var label: String {
        switch self {
        case .creativity: return "Creativity"
        case .physical: return "Physical Activity"
        case .housework: return "Housework"
        }
    }
}

struct MomentumAction {
    let title: String
    let desc: String
    let label: String
    let hue: Double
    let meters: Int
}

let momentumActionsByCategory: [MomentumCategory: [MomentumAction]] = [
    .creativity: [
        MomentumAction(title: "Doodle for two minutes", desc: "Grab any pen and fill one corner of a page.", label: "photo · quick doodle", hue: 20, meters: 60),
        MomentumAction(title: "Take one photo", desc: "Find one thing nearby that looks interesting today.", label: "photo · phone camera", hue: 300, meters: 55),
        MomentumAction(title: "Write one sentence", desc: "Describe how this moment feels. No editing allowed.", label: "photo · notebook and pen", hue: 230, meters: 70),
        MomentumAction(title: "Hum a tune", desc: "Any song, thirty seconds, just for you.", label: "photo · headphones", hue: 150, meters: 50),
    ],
    .physical: [
        MomentumAction(title: "Take a short walk", desc: "Walk for 5 minutes around your current location. No destination needed.", label: "photo · short walk outside", hue: 130, meters: 100),
        MomentumAction(title: "Stretch your arms", desc: "Reach up as high as you can and hold for three slow breaths.", label: "photo · morning stretch", hue: 300, meters: 55),
        MomentumAction(title: "Drink a glass of water", desc: "Fill a glass and sip it slowly, start to finish.", label: "photo · glass of water", hue: 230, meters: 50),
        MomentumAction(title: "Ten slow squats", desc: "Stand up and do ten, at whatever pace feels easy.", label: "photo · easy squats", hue: 60, meters: 80),
    ],
    .housework: [
        MomentumAction(title: "Make your bed", desc: "Straighten the sheets and set the pillow back in place.", label: "photo · freshly made bed", hue: 60, meters: 65),
        MomentumAction(title: "Wash one dish", desc: "Just one. The rest can wait.", label: "photo · clean dish", hue: 230, meters: 50),
        MomentumAction(title: "Clear one surface", desc: "Pick one shelf or table and clear only that.", label: "photo · tidy shelf", hue: 130, meters: 90),
        MomentumAction(title: "Open a window", desc: "Let fresh air in for two minutes and just breathe.", label: "photo · open window", hue: 190, meters: 50),
    ],
]
