import SwiftUI

struct Theme {
    static let primaryBlue = Color(red: 0.0, green: 0.52, blue: 1.0) // #0084FF
    static let darkBlue = Color(red: 0.0, green: 0.40, blue: 0.85)
    static let lightBlue = Color(red: 0.90, green: 0.95, blue: 1.0)
    
    // Backgrounds
    static let chatBackgroundDark = Color(red: 0.04, green: 0.08, blue: 0.10) // #0B141A
    static let chatBackgroundLight = Color(red: 0.94, green: 0.96, blue: 0.98) // #F0F4F8
    
    static let surfaceDark = Color(red: 0.07, green: 0.11, blue: 0.13) // #111B21
    static let surfaceLight = Color.white
    
    // Chat Bubbles
    static let outgoingBubbleDark = Color(red: 0.0, green: 0.35, blue: 0.70)
    static let outgoingBubbleLight = Color(red: 0.0, green: 0.52, blue: 1.0)
    
    static let incomingBubbleDark = Color(red: 0.12, green: 0.16, blue: 0.19)
    static let incomingBubbleLight = Color.white
    
    // Text
    static let textPrimaryDark = Color.white
    static let textPrimaryLight = Color(red: 0.07, green: 0.11, blue: 0.13)
    
    static let textSecondaryDark = Color(red: 0.53, green: 0.60, blue: 0.65)
    static let textSecondaryLight = Color(red: 0.40, green: 0.47, blue: 0.51)
    
    static let dividerColor = Color(red: 0.85, green: 0.88, blue: 0.92).opacity(0.4)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
