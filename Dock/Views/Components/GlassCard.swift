//
//  GlassCard.swift
//  Dock
//
//  Modern glass morphism card component
//

import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    
    init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Frosted Card

struct FrostedCard<Content: View>: View {
    let content: Content
    var intensity: Material = .ultraThinMaterial
    
    init(
        intensity: Material = .ultraThinMaterial,
        @ViewBuilder content: () -> Content
    ) {
        self.intensity = intensity
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(intensity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Gradient Card

struct GradientCard<Content: View>: View {
    let content: Content
    let gradient: LinearGradient
    
    init(
        colors: [Color] = [.blue, .purple],
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Score Card

struct ScoreCard: View {
    let score: Double
    let recommendation: InvestmentRecommendation
    let metrics: DealMetrics
    
    var body: some View {
        VStack(spacing: 16) {
            // Score ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(recommendation.color.opacity(0.2), lineWidth: 12)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        recommendation.color,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: score)
                
                // Score text
                VStack(spacing: 4) {
                    Text("\(Int(score))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    
                    Text("SCORE")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            
            // Recommendation
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: recommendation.icon)
                    Text(recommendation.rawValue)
                }
                .font(.headline)
                .foregroundStyle(recommendation.color)
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            // Key metrics
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text(metrics.dealEconomics.inPlaceCapRate.asPercent())
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Text("Cap Rate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(spacing: 2) {
                    Text(metrics.dealEconomics.cashOnCashReturn.asPercent())
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Text("Cash-on-Cash")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(spacing: 2) {
                    Text(String(format: "%.2fx", metrics.dealEconomics.dscr))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Text("DSCR")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Action Card

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Glass Cards") {
    ScrollView {
        VStack(spacing: 20) {
            GlassCard {
                VStack(alignment: .leading) {
                    Text("Glass Card")
                        .font(.headline)
                    Text("With modern glass morphism")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            FrostedCard {
                Text("Frosted Card")
            }
            
            GradientCard(colors: [.green, .blue]) {
                Text("Gradient Card")
                    .foregroundStyle(.white)
            }
            
            ActionCard(
                icon: "house.fill",
                title: "View Property",
                subtitle: "See full details",
                color: .blue
            ) {}
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
