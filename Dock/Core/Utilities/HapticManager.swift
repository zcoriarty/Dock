//
//  HapticManager.swift
//  Dock
//
//  Haptic feedback manager for enhanced UX
//

import UIKit
import SwiftUI

@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        prepareAll()
    }
    
    private func prepareAll() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    // MARK: - Impact Feedback
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1.0) {
        switch style {
        case .light:
            impactLight.impactOccurred(intensity: intensity)
        case .medium:
            impactMedium.impactOccurred(intensity: intensity)
        case .heavy:
            impactHeavy.impactOccurred(intensity: intensity)
        case .soft:
            impactSoft.impactOccurred(intensity: intensity)
        case .rigid:
            impactRigid.impactOccurred(intensity: intensity)
        @unknown default:
            impactMedium.impactOccurred(intensity: intensity)
        }
    }
    
    // MARK: - Selection Feedback
    
    func selection() {
        selectionGenerator.selectionChanged()
    }
    
    // MARK: - Notification Feedback
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }
    
    // MARK: - App-Specific Patterns
    
    func tap() {
        impact(.light)
    }
    
    func buttonPress() {
        impact(.medium)
    }
    
    func success() {
        notification(.success)
    }
    
    func warning() {
        notification(.warning)
    }
    
    func error() {
        notification(.error)
    }
    
    func toggle() {
        impact(.rigid, intensity: 0.7)
    }
    
    func propertyAdded() {
        Task { @MainActor in
            impact(.medium)
            try? await Task.sleep(for: .milliseconds(100))
            notification(.success)
        }
    }
    
    func scoreCalculated(_ recommendation: InvestmentRecommendation) {
        switch recommendation {
        case .strongBuy, .buy:
            success()
        case .hold:
            impact(.medium)
        case .caution:
            warning()
        case .pass:
            error()
        }
    }
    
    func drag() {
        impact(.soft, intensity: 0.5)
    }
    
    func drop() {
        impact(.medium)
    }
    
    func refresh() {
        impact(.light)
    }
    
    func editField() {
        impact(.light, intensity: 0.6)
    }
    
    func slider() {
        impact(.soft, intensity: 0.3)
    }
}

// MARK: - View Extension

extension View {
    func hapticOnTap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                Task { @MainActor in
                    HapticManager.shared.impact(style)
                }
            }
        )
    }
    
    func hapticOnChange<V: Equatable>(of value: V) -> some View {
        self.onChange(of: value) { _, _ in
            Task { @MainActor in
                HapticManager.shared.selection()
            }
        }
    }
}
