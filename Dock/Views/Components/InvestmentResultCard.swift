//
//  InvestmentResultCard.swift
//  Dock
//
//  Property card for investment search results
//

import SwiftUI

struct InvestmentResultCard: View {
    let result: InvestmentSearchResult
    let cardBackground: Color
    let colorScheme: ColorScheme
    let isTracked: Bool
    let onAdd: () -> Void
    let onOpen: () -> Void

    private var score: Double {
        result.metrics.score
    }

    private var capRateText: String {
        result.metrics.capRate.map { $0.asPercent() } ?? "--"
    }

    private var cashOnCashText: String {
        result.metrics.cashOnCash.map { $0.asPercent() } ?? "--"
    }

    private var rentText: String {
        result.metrics.estimatedRent.map { $0.asCurrency } ?? "--"
    }

    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 14) {
                    propertyImage
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center) {
                            Text(result.property.askingPrice.asCompactCurrency)
                                .font(.system(.title3, design: .rounded, weight: .bold))

                            Spacer()

                            scoreBadge
                        }

                        Text(result.property.address)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text("\(result.property.city), \(result.property.state)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            MetricPill(label: "Cap", value: capRateText)
                            MetricPill(label: "CoC", value: cashOnCashText)
                            MetricPill(label: "Rent", value: rentText)
                        }
                    }
                }
                .padding(10)

                Button(action: onAdd) {
                    Image(systemName: isTracked ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isTracked ? .green : .primary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(10)
                .disabled(isTracked)
            }
        }
        .buttonStyle(.plain)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder
    private var propertyImage: some View {
        if let firstURL = result.property.photoURLs.first,
           let url = URL(string: firstURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderImage
                case .empty:
                    placeholderImage
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.06),
                        Color.primary.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: result.property.propertyType.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.primary.opacity(0.2))
            }
    }

    private var scoreBadge: some View {
        HStack(spacing: 6) {
            Text("\(Int(score))")
                .font(.system(.subheadline, design: .rounded, weight: .bold))

            Circle()
                .fill(scoreColor)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var scoreColor: Color {
        switch score {
        case 85...:
            return .green
        case 70..<85:
            return .yellow
        case 55..<70:
            return .orange
        default:
            return .red
        }
    }
}

private struct MetricPill: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
    }
}
