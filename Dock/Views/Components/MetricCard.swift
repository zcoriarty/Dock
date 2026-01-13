//
//  MetricCard.swift
//  Dock
//
//  Reusable metric display components
//

import SwiftUI

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let score: MetricScore?
    let icon: String?
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        score: MetricScore? = nil,
        icon: String? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.score = score
        self.icon = icon
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let score = score {
                    Image(systemName: score.icon)
                        .font(.caption)
                        .foregroundStyle(score.color)
                }
            }
            
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(score?.color ?? .primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Large Metric Card

struct LargeMetricCard: View {
    let title: String
    let value: String
    let trend: TrendDirection?
    let trendValue: String?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                
                if let trend = trend, let trendValue = trendValue {
                    HStack(spacing: 2) {
                        Image(systemName: trend.rawValue)
                            .font(.caption2)
                        Text(trendValue)
                            .font(.caption)
                    }
                    .foregroundStyle(trend.color)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Score Badge

struct ScoreBadge: View {
    let score: Double
    let recommendation: InvestmentRecommendation
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(recommendation.color.opacity(0.3), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(recommendation.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(score))")
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.rawValue)
                    .font(.headline)
                    .foregroundStyle(recommendation.color)
                
                Text("Investment Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let metric: ScoredMetric
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name)
                    .font(.subheadline)
                
                Text("Target: \(metric.displayThreshold)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(metric.displayValue)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(metric.score.color)
                
                Image(systemName: metric.score.icon)
                    .font(.caption)
                    .foregroundStyle(metric.score.color)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Market Indicator Row

struct MarketIndicatorRow: View {
    let title: String
    let indicator: MarketIndicator
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                
                Text(indicator.description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Text(indicator.displayValue)
                    .font(.system(.body, design: .rounded, weight: .medium))
                
                Image(systemName: indicator.trend.rawValue)
                    .font(.caption)
                    .foregroundStyle(indicator.trend.color)
                
                Text(indicator.signal.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(indicator.signal.color.opacity(0.2))
                    .foregroundStyle(indicator.signal.color)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Sensitivity Row

struct SensitivityRow: View {
    let result: SensitivityResult
    let baseValue: Double
    
    var body: some View {
        HStack {
            Text(result.label)
                .font(.subheadline)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(result.cashFlow.asCurrency)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(result.cashFlow >= 0 ? .primary : Color.red)
                
                HStack(spacing: 2) {
                    Image(systemName: result.deltaFromBase >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(abs(result.deltaFromBase).asCurrency)
                        .font(.caption2)
                }
                .foregroundStyle(result.deltaFromBase >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Editable Metric

struct EditableMetric: View {
    let title: String
    @Binding var value: Double
    let format: MetricFormat
    let range: ClosedRange<Double>
    let step: Double
    let onEdit: () -> Void
    
    enum MetricFormat {
        case currency
        case percent
        case decimal
        case years
    }
    
    @State private var isEditing: Bool = false
    
    var displayValue: String {
        switch format {
        case .currency:
            return value.asCurrency
        case .percent:
            return (value * 100).formatted() + "%"
        case .decimal:
            return value.formatted()
        case .years:
            return "\(Int(value)) years"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Text(displayValue)
                    .font(.system(.body, design: .rounded, weight: .medium))
                
                Spacer()
                
                Button {
                    isEditing.toggle()
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            if isEditing {
                VStack(spacing: 4) {
                    Slider(value: $value, in: range, step: step) { editing in
                        if !editing {
                            onEdit()
                        }
                    }
                    .tint(.accentColor)
                    
                    HStack {
                        Text(formatValue(range.lowerBound))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(formatValue(range.upperBound))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
    
    private func formatValue(_ val: Double) -> String {
        switch format {
        case .currency:
            return val.asCompactCurrency
        case .percent:
            return (val * 100).asDecimal + "%"
        case .decimal:
            return val.asDecimal
        case .years:
            return "\(Int(val))y"
        }
    }
}

// MARK: - Previews

#Preview("Metric Card") {
    VStack {
        MetricCard(
            title: "Cap Rate",
            value: "6.5%",
            subtitle: "Target: 6.0%",
            score: .meets,
            icon: "chart.line.uptrend.xyaxis"
        )
        
        LargeMetricCard(
            title: "Cash Flow",
            value: "$1,250/mo",
            trend: .up,
            trendValue: "+12%",
            color: .green
        )
        
        ScoreBadge(score: 78, recommendation: .buy)
    }
    .padding()
}
