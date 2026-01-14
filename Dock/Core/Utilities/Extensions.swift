//
//  Extensions.swift
//  Dock
//
//  Common utility extensions
//

import Foundation
import SwiftUI

// MARK: - Double Extensions

extension Double {
    /// Format as currency
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "$0"
    }
    
    /// Format as compact currency (e.g., $1.2M, $450K)
    var asCompactCurrency: String {
        let absValue = abs(self)
        let sign = self < 0 ? "-" : ""
        
        if absValue >= 1_000_000 {
            return "\(sign)$\(String(format: "%.1f", absValue / 1_000_000))M"
        } else if absValue >= 1_000 {
            return "\(sign)$\(String(format: "%.0f", absValue / 1_000))K"
        } else {
            return "\(sign)$\(String(format: "%.0f", absValue))"
        }
    }
    
    /// Format as percentage (value stored as decimal, e.g. 0.07 = 7%)
    func asPercent(decimals: Int = 2) -> String {
        String(format: "%.\(decimals)f%%", self * 100)
    }
    
    /// Format with comma separators
    var withCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }
    
    /// Format as decimal with specific precision
    func formatted(decimals: Int = 2) -> String {
        String(format: "%.\(decimals)f", self)
    }
    
    /// Format as decimal string (2 decimal places)
    var asDecimal: String {
        String(format: "%.2f", self)
    }
}

// MARK: - Int Extensions

extension Int {
    /// Format with comma separators
    var withCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }
    
    /// Format as square feet
    var asSqft: String {
        "\(withCommas) sq ft"
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format as short date (e.g., "Jan 15, 2024")
    var shortFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Format as relative time (e.g., "2 hours ago")
    var relativeFormat: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is in the past
    var isInPast: Bool {
        self < Date()
    }
}

// MARK: - String Extensions

extension String {
    /// Trim whitespace and newlines
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if string is a valid email
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return range(of: emailRegex, options: .regularExpression) != nil
    }
    
    /// Check if string is empty or contains only whitespace
    var isBlank: Bool {
        trimmed.isEmpty
    }
    
    /// Convert to URL if valid
    var asURL: URL? {
        URL(string: self)
    }
    
    /// Capitalize first letter only
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a modifier conditionally
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Hide keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Add a card background
    func cardBackground() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Color Extensions

extension Color {
    /// Create color from hex string
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

// MARK: - URL Validation Extensions

extension String {
    /// Check if string is a valid property listing URL (Zillow, Redfin, or Realtor.com)
    var isPropertyListingURL: Bool {
        let lowercased = self.lowercased()
        return lowercased.contains("zillow.com") ||
               lowercased.contains("redfin.com") ||
               lowercased.contains("realtor.com")
    }
    
    /// Get the source from a listing URL
    var listingSource: String? {
        let lowercased = self.lowercased()
        if lowercased.contains("zillow.com") { return "Zillow" }
        if lowercased.contains("redfin.com") { return "Redfin" }
        if lowercased.contains("realtor.com") { return "Realtor.com" }
        return nil
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safe subscript that returns nil for out of bounds
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Optional Extensions

extension Optional where Wrapped == String {
    /// Returns true if nil or empty
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

extension String {
    /// Returns nil if the string is empty, otherwise returns self
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
