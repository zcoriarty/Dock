//
//  PropertyCard.swift
//  Dock
//
//  Property card for home screen list
//

import SwiftUI

struct PropertyCard: View {
    let property: Property
    let onPin: () -> Void
    let onDelete: () -> Void
    
    @State private var showingActions: Bool = false
    
    private var metrics: DealMetrics {
        property.metrics
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Image on left
            propertyImage
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Content on right
            VStack(alignment: .leading, spacing: 6) {
                // Address and score
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(property.address)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        Text("\(property.city), \(property.state) \(property.zipCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        if property.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        
                        ScoreMiniBadge(
                            score: metrics.overallScore,
                            recommendation: metrics.recommendation
                        )
                    }
                }
                
                // Quick stats
                HStack(spacing: 10) {
                    StatPill(icon: "bed.double.fill", value: "\(property.bedrooms)")
                    StatPill(icon: "shower.fill", value: String(format: "%.1f", property.bathrooms))
                    StatPill(icon: "square.fill", value: property.squareFeet.withCommas)
                }
                
                // Key metrics row
                HStack(spacing: 16) {
                    MetricPill(title: "Price", value: property.askingPrice.asCompactCurrency)
                    MetricPill(title: "Cap", value: metrics.dealEconomics.inPlaceCapRate.asPercent())
                    MetricPill(title: "CoC", value: metrics.dealEconomics.cashOnCashReturn.asPercent())
                    MetricPill(title: "CF/mo", value: metrics.dealEconomics.monthlyCashFlow.asCompactCurrency)
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .contextMenu {
            Button {
                onPin()
            } label: {
                Label(property.isPinned ? "Unpin" : "Pin", systemImage: property.isPinned ? "pin.slash" : "pin")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private var propertyImage: some View {
        if let photoData = property.primaryPhotoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let firstURL = property.photoURLs.first,
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
                    colors: [Color(.systemGray5), Color(.systemGray4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: property.propertyType.icon)
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
    }
}

// MARK: - Supporting Views


struct MetricPill: View {
    let title: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

struct ScoreMiniBadge: View {
    let score: Double
    let recommendation: InvestmentRecommendation
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: recommendation.icon)
                .font(.caption2)
            
            Text("\(Int(score))")
                .font(.system(.caption, design: .rounded, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(recommendation.color)
        .clipShape(Capsule())
    }
}

// MARK: - Compact Card

struct PropertyCompactCard: View {
    let property: Property
    
    private var metrics: DealMetrics {
        property.metrics
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .overlay {
                    if let photoData = property.primaryPhotoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: property.propertyType.icon)
                            .foregroundStyle(.tertiary)
                    }
                }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(property.address)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(property.city), \(property.state)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Text(property.askingPrice.asCompactCurrency)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text("\(metrics.dealEconomics.cashOnCashReturn.asPercent) CoC")
                        .font(.caption)
                        .foregroundStyle(metrics.dealEconomics.cashOnCashReturn >= property.thresholds.targetCashOnCash ? .green : .secondary)
                }
            }
            
            Spacer()
            
            // Score
            VStack(spacing: 2) {
                Text("\(Int(metrics.overallScore))")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(metrics.recommendation.color)
                
                Image(systemName: metrics.recommendation.icon)
                    .font(.caption2)
                    .foregroundStyle(metrics.recommendation.color)
            }
            
            if property.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Property Card") {
    ScrollView {
        VStack(spacing: 16) {
            PropertyCard(
                property: .preview,
                onPin: {},
                onDelete: {}
            )
            
            PropertyCompactCard(property: .preview)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

// MARK: - Preview Helper

extension Property {
    static var preview: Property {
        Property(
            address: "123 Investment Lane",
            city: "Austin",
            state: "TX",
            zipCode: "78701",
            askingPrice: 450000,
            bedrooms: 3,
            bathrooms: 2,
            squareFeet: 1800,
            lotSize: 6500,
            yearBuilt: 1985,
            propertyType: .singleFamily,
            taxAssessedValue: 380000,
            annualTaxes: 8500,
            estimatedRentPerUnit: 2400,
            estimatedTotalRent: 2400,
            financing: FinancingInputs(
                purchasePrice: 450000,
                loanAmount: 337500,
                interestRate: 0.07,
                loanTermYears: 30,
                ltv: 0.75,
                closingCosts: 12000
            )
        )
    }
}
