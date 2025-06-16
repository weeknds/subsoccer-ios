import SwiftUI

struct AppTheme {
    // MARK: - Colors
    static let primaryBackground = Color.black
    static let secondaryBackground = Color(hex: "#1C1C1E")
    static let accentColor = Color(hex: "#00FF00")
    static let primaryText = Color.white
    static let secondaryText = Color(hex: "#8E8E93")
    
    // MARK: - Design System
    static let cornerRadius: CGFloat = 12
    static let largePadding: CGFloat = 16
    static let standardPadding: CGFloat = 8
    
    // MARK: - Typography
    static let headerFont = Font.system(.largeTitle, design: .default, weight: .bold)
    static let titleFont = Font.system(.title2, design: .default, weight: .semibold)
    static let subheadFont = Font.system(.subheadline, design: .default, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .default, weight: .regular)
    static let captionFont = Font.system(.caption, design: .default, weight: .medium)
}

// MARK: - Common Styles

struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(AppTheme.bodyFont)
            .foregroundColor(AppTheme.primaryText)
            .padding(AppTheme.standardPadding)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(AppTheme.cornerRadius)
    }
}

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