//
//  Theme.swift
//  Dock
//
//  App-wide styling and theming
//

import SwiftUI

// MARK: - Theme

enum Theme {
    // MARK: - Colors
    
    enum Colors {
        // Primary
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
        
        // Text
        static let primaryText = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText = Color(.tertiaryLabel)
        
        // Semantic
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        static let info = Color.blue
        
        // Investment scoring
        static let exceeds = Color(hex: "#00C853") ?? .green
        static let meets = Color(hex: "#4CAF50") ?? .green
        static let borderline = Color(hex: "#FFC107") ?? .yellow
        static let fails = Color(hex: "#F44336") ?? .red
        
        // Recommendations
        static let strongBuy = Color(hex: "#00C853") ?? .green
        static let buy = Color(hex: "#4CAF50") ?? .green
        static let hold = Color(hex: "#FFC107") ?? .yellow
        static let caution = Color(hex: "#FF9800") ?? .orange
        static let pass = Color(hex: "#F44336") ?? .red
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
        
        // Monospace for numbers
        static let metric = Font.system(.title2, design: .rounded, weight: .semibold)
        static let metricLarge = Font.system(.title, design: .rounded, weight: .bold)
        static let metricSmall = Font.system(.body, design: .rounded, weight: .medium)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 100
    }
    
    // MARK: - Shadows
    
    enum Shadows {
        static let small = ShadowStyle(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        static let large = ShadowStyle(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
    
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
}

// MARK: - View Extensions

extension View {
    func themeCardStyle() -> some View {
        self
            .background(Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large, style: .continuous))
            .shadow(
                color: Theme.Shadows.medium.color,
                radius: Theme.Shadows.medium.radius,
                x: Theme.Shadows.medium.x,
                y: Theme.Shadows.medium.y
            )
    }
    
    func themeSectionStyle() -> some View {
        self
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
    }
    
    func themeInputStyle() -> some View {
        self
            .padding(Theme.Spacing.sm)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
    }
}

// MARK: - Metric Color Helper

extension Double {
    func scoreColor(target: Double, higherIsBetter: Bool = true) -> Color {
        if higherIsBetter {
            if self >= target * 1.1 { return Theme.Colors.exceeds }
            if self >= target { return Theme.Colors.meets }
            if self >= target * 0.85 { return Theme.Colors.borderline }
            return Theme.Colors.fails
        } else {
            if self <= target * 0.9 { return Theme.Colors.exceeds }
            if self <= target { return Theme.Colors.meets }
            if self <= target * 1.15 { return Theme.Colors.borderline }
            return Theme.Colors.fails
        }
    }
}
