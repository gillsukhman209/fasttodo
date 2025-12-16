import SwiftUI

// MARK: - App Theme Manager

@Observable
class ThemeManager {
    static let shared = ThemeManager()
    var isDarkMode: Bool = true
}

// MARK: - Adaptive Design System

enum Theme {

    static var isDark: Bool { ThemeManager.shared.isDarkMode }

    // MARK: - Colors (Adaptive)
    enum Colors {
        // Backgrounds
        static var bg: Color {
            isDark ? Color(hex: "0D0D0F") : Color(hex: "FAFAFA")
        }
        static var bgSecondary: Color {
            isDark ? Color(hex: "1A1A1E") : Color(hex: "F0F0F2")
        }
        static var bgTertiary: Color {
            isDark ? Color(hex: "252529") : Color(hex: "E8E8EC")
        }

        // Text
        static var textPrimary: Color {
            isDark ? .white : Color(hex: "0D0D0F")
        }
        static var textSecondary: Color {
            isDark ? Color(hex: "8E8E93") : Color(hex: "6E6E73")
        }
        static var textMuted: Color {
            isDark ? Color(hex: "48484A") : Color(hex: "AEAEB2")
        }

        // Accent - Electric/Vibrant
        static let accent = Color(hex: "FF6B35")  // Vibrant coral/orange
        static let accentAlt = Color(hex: "FF8F65")

        // Success
        static let success = Color(hex: "32D74B")

        // Borders
        static var border: Color {
            isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        }
    }

    // MARK: - Typography (Bold & Confident)
    enum Fonts {
        static let mega = SwiftUI.Font.system(size: 56, weight: .bold, design: .rounded)
        static let huge = SwiftUI.Font.system(size: 42, weight: .bold, design: .rounded)
        static let large = SwiftUI.Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = SwiftUI.Font.system(size: 20, weight: .semibold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 17, weight: .medium, design: .rounded)
        static let caption = SwiftUI.Font.system(size: 13, weight: .semibold, design: .rounded)
        static let micro = SwiftUI.Font.system(size: 11, weight: .bold, design: .rounded)
    }

    // MARK: - Spacing
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Radius
    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let full: CGFloat = 999
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
