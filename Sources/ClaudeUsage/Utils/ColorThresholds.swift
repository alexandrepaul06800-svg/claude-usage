import SwiftUI

let claudeBackground = Color(hex: 0x1A1A1A)
let claudeSecondaryBackground = Color(hex: 0x242424)
let claudeCard = Color(hex: 0x2C2C2C)
let claudeBorder = Color(hex: 0x383838)
let claudeTextPrimary = Color(hex: 0xE8E6E0)
let claudeTextSecondary = Color(hex: 0x8C8A85)
let claudeAmber = Color(hex: 0xD4800A)
let claudeGreen = Color(hex: 0x4CAF7D)
let claudeRed = Color(hex: 0xE05252)
let claudeYellow = Color(hex: 0xC9A227)

func colorForUsage(_ ratio: Double) -> Color {
    switch ratio {
    case 0..<0.75:
        claudeGreen
    case 0.75..<0.9:
        claudeYellow
    default:
        claudeRed
    }
}

func statusForUsage(_ ratio: Double) -> UsageStatus {
    switch ratio {
    case 0..<0.75:
        .ok
    case 0.75..<0.9:
        .warning
    default:
        .limitNear
    }
}

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
