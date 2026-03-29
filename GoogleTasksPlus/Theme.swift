import SwiftUI

enum DB {
    // Primary brand
    static let red = Color(hex: "#FF3621")
    static let redDark = Color(hex: "#E02E1B")

    // Navigation / chrome
    static let navBackground = Color(hex: "#1B3139")
    static let navBackgroundLight = Color(hex: "#2D4A54")

    // Backgrounds
    static let background = Color(hex: "#FFFFFF")
    static let surface = Color(hex: "#F5F7FA")
    static let surfaceHover = Color(hex: "#EDF0F5")

    // Text
    static let textPrimary = Color(hex: "#1B1F24")
    static let textSecondary = Color(hex: "#6B7785")
    static let textOnDark = Color(hex: "#FFFFFF")
    static let textOnDarkMuted = Color(hex: "#A8B5BF")

    // Borders
    static let border = Color(hex: "#E2E8F0")
    static let borderLight = Color(hex: "#F0F3F7")

    // Status
    static let success = Color(hex: "#00A972")
    static let warning = Color(hex: "#F5A623")

    // Tags
    static let tagBackground = Color(hex: "#EBF5FF")
    static let tagText = Color(hex: "#1A73E8")
    static let tagBorder = Color(hex: "#C2DCFF")

    // Shadows
    static let cardShadow = Color.black.opacity(0.06)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
