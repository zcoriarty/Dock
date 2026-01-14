//
//  PropertyCard.swift
//  Dock
//
//  Property card for home screen list
//

import SwiftUI

struct PropertyCard: View {
    let property: Property
    let cardBackground: Color
    let colorScheme: ColorScheme
    let onPin: () -> Void
    let onDelete: () -> Void
    
    private var score: Double {
        property.metrics.overallScore
    }
    
    private var recommendation: InvestmentRecommendation {
        property.metrics.recommendation
    }
    
    var body: some View {
        cardLayout
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
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
    
    // MARK: - Card Layout
    
    private var cardLayout: some View {
        HStack(spacing: 14) {
            // Property image or placeholder on the left
            propertyImage
                .frame(width: 100)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Top row: Price, score badge, pin
                HStack(alignment: .center) {
                    Text(property.askingPrice.asCompactCurrency)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    
                    Spacer()
                    
                    scoreBadge
                    
                    if property.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                // Address
                Text(property.address)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text("\(property.city), \(property.state)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Stats row
                HStack(spacing: 12) {
                    CompactStat(value: "\(property.bedrooms)", label: "bd")
                    CompactStat(value: String(format: "%.1f", property.bathrooms), label: "ba")
                    CompactStat(value: property.squareFeet.withCommas, label: "sqft")
                    
                    Spacer()
                    
                    cashFlowBadge
                }
            }
        }
        .padding(10)
    }
    
    // MARK: - Property Image
    
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
                    colors: [
                        Color.primary.opacity(0.06),
                        Color.primary.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: property.propertyType.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.primary.opacity(0.2))
            }
    }
    
    private var scoreBadge: some View {
        HStack(spacing: 6) {
            Text("\(Int(score))")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
            
            Circle()
                .fill(recommendation.color)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private var cashFlowBadge: some View {
        let cashFlow = property.metrics.dealEconomics.monthlyCashFlow
        return Text(cashFlow.asCurrency)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(cashFlow >= 0 ? .green : .red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((cashFlow >= 0 ? Color.green : Color.red).opacity(0.1))
            .clipShape(Capsule())
    }
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
