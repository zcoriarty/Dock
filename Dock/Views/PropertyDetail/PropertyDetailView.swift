//
//  PropertyDetailView.swift
//  Dock
//
//  Property detail with all underwriting metrics
//

import SwiftUI

struct PropertyDetailView: View {
    @State private var viewModel: PropertyDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    
    init(property: Property, onSave: @escaping (Property) async -> Void) {
        _viewModel = State(initialValue: PropertyDetailViewModel(property: property, onSave: onSave))
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                propertyHeader
                
                // Content based on section
                VStack(spacing: 24) {
                    sectionPicker
                    
                    Group {
                        switch viewModel.activeSection {
                        case .summary:
                            summarySection
                        case .economics:
                            economicsSection
                        case .market:
                            marketSection
                        case .risk:
                            riskSection
                        case .notes:
                            notesSection
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task {
                            await viewModel.fetchAllData()
                        }
                    } label: {
                        Label("Refresh Data", systemImage: "arrow.clockwise")
                    }
                    
                    Button {
                        viewModel.showingFinancing = true
                    } label: {
                        Label("Edit Financing", systemImage: "slider.horizontal.3")
                    }
                    
                    Divider()
                    
                    Button {
                        Task {
                            await viewModel.save()
                        }
                    } label: {
                        Label("Save Changes", systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingFinancing) {
            FinancingSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingSensitivity) {
            SensitivitySheet(metrics: viewModel.metrics)
        }
    }
    
    // MARK: - Property Header
    
    private var propertyHeader: some View {
        VStack(spacing: 0) {
            // Photo - only show if we have one
            if let photoData = viewModel.property.primaryPhotoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .clipped()
            }
            
            // Property info
            VStack(alignment: .leading, spacing: 16) {
                // Price and score row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.property.askingPrice.asCompactCurrency)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        Text(viewModel.property.address)
                            .font(.body)
                            .foregroundStyle(.primary)
                        
                        Text("\(viewModel.property.city), \(viewModel.property.state) \(viewModel.property.zipCode)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        // View Listing Link
                        if let url = viewModel.property.viewableListingURL {
                            Button {
                                openURL(url)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                    Text("View on \(viewModel.property.listingSource ?? "Zillow")")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                    
                    Spacer()
                    
                    // Score circle
                    ModernScoreBadge(
                        score: viewModel.metrics.overallScore,
                        recommendation: viewModel.metrics.recommendation
                    )
                }
                
                // Quick stats
                HStack(spacing: 0) {
                    QuickStat(value: "\(viewModel.property.bedrooms)", label: "Beds")
                    
                    Divider()
                        .frame(height: 32)
                        .padding(.horizontal, 16)
                    
                    QuickStat(value: String(format: "%.1f", viewModel.property.bathrooms), label: "Baths")
                    
                    Divider()
                        .frame(height: 32)
                        .padding(.horizontal, 16)
                    
                    QuickStat(value: viewModel.property.squareFeet.withCommas, label: "Sq Ft")
                    
                    Divider()
                        .frame(height: 32)
                        .padding(.horizontal, 16)
                    
                    QuickStat(value: "\(viewModel.property.yearBuilt)", label: "Built")
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(backgroundColor)
        }
    }
    
    // MARK: - Section Picker
    
    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PropertyDetailViewModel.DetailSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.activeSection = section
                        }
                        Task { @MainActor in
                            HapticManager.shared.selection()
                        }
                    } label: {
                        Text(section.rawValue)
                            .font(.subheadline)
                            .fontWeight(viewModel.activeSection == section ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                viewModel.activeSection == section
                                ? Color.primary
                                : Color.clear
                            )
                            .foregroundStyle(
                                viewModel.activeSection == section
                                ? (colorScheme == .dark ? Color.black : Color.white)
                                : .primary
                            )
                            .clipShape(Capsule())
                            .overlay {
                                if viewModel.activeSection != section {
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: 20) {
            // Hero metrics
            HStack(spacing: 12) {
                HeroMetricCard(
                    title: "Monthly Cash Flow",
                    value: viewModel.metrics.dealEconomics.monthlyCashFlow.asCurrency,
                    isPositive: viewModel.metrics.dealEconomics.monthlyCashFlow >= 0,
                    background: cardBackground
                )
                
                HeroMetricCard(
                    title: "Cap Rate",
                    value: viewModel.metrics.dealEconomics.inPlaceCapRate.asPercent(),
                    isPositive: viewModel.metrics.dealEconomics.inPlaceCapRate >= viewModel.property.thresholds.targetCapRate,
                    background: cardBackground
                )
            }
            .padding(.horizontal, 20)
            
            // Metrics list
            VStack(alignment: .leading, spacing: 12) {
                Text("Performance")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.metrics.scoredMetrics.enumerated()), id: \.element.id) { index, metric in
                        ModernMetricRow(metric: metric)
                        
                        if index < viewModel.metrics.scoredMetrics.count - 1 {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            }
            
            // Recommendation
            VStack(alignment: .leading, spacing: 12) {
                Text("Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                
                HStack(spacing: 16) {
                    Circle()
                        .fill(viewModel.metrics.recommendation.color)
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: viewModel.metrics.recommendation.icon)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.metrics.recommendation.rawValue)
                            .font(.headline)
                        
                        Text(viewModel.metrics.recommendation.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Economics Section
    
    private var economicsSection: some View {
        VStack(spacing: 24) {
            // Income
            ModernSection(title: "Income", background: cardBackground) {
                VStack(spacing: 0) {
                    ModernEconomicsRow(title: "Gross Potential Rent", value: viewModel.metrics.dealEconomics.grossPotentialRent.asCurrency)
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(title: "Vacancy Loss", value: "-\(viewModel.metrics.dealEconomics.vacancyLoss.asCurrency)", valueColor: .red.opacity(0.8))
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(title: "Effective Gross Income", value: viewModel.metrics.dealEconomics.effectiveGrossIncome.asCurrency, isHighlighted: true)
                }
            }
            
            // Expenses
            ModernSection(title: "Operating Expenses", background: cardBackground) {
                VStack(spacing: 0) {
                    ModernEconomicsRow(title: "Property Taxes", value: viewModel.metrics.dealEconomics.expenseBreakdown.taxes.asCurrency)
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(title: "Insurance", value: viewModel.metrics.dealEconomics.expenseBreakdown.insurance.asCurrency)
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(title: "Management", value: viewModel.metrics.dealEconomics.expenseBreakdown.management.asCurrency)
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(title: "Repairs/Maintenance", value: viewModel.metrics.dealEconomics.expenseBreakdown.repairs.asCurrency)
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(title: "CapEx Reserve", value: viewModel.metrics.dealEconomics.expenseBreakdown.capexReserve.asCurrency)
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(title: "Other", value: viewModel.metrics.dealEconomics.expenseBreakdown.other.asCurrency)
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(title: "Total Expenses", value: viewModel.metrics.dealEconomics.totalOperatingExpenses.asCurrency, isHighlighted: true)
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(title: "Expense Ratio", value: viewModel.metrics.dealEconomics.expenseBreakdown.expenseRatio.asPercent(), isHighlighted: true)
                }
            }
            
            // Returns
            ModernSection(title: "Returns", background: cardBackground) {
                VStack(spacing: 0) {
                    ModernEconomicsRow(title: "Net Operating Income", value: viewModel.metrics.dealEconomics.netOperatingIncome.asCurrency, isHighlighted: true)
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(title: "Annual Debt Service", value: "-\(viewModel.metrics.dealEconomics.annualDebtService.asCurrency)")
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Annual Cash Flow",
                        value: viewModel.metrics.dealEconomics.annualCashFlow.asCurrency,
                        valueColor: viewModel.metrics.dealEconomics.annualCashFlow >= 0 ? .green : .red,
                        isHighlighted: true
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Monthly Cash Flow",
                        value: viewModel.metrics.dealEconomics.monthlyCashFlow.asCurrency,
                        valueColor: viewModel.metrics.dealEconomics.monthlyCashFlow >= 0 ? .green : .red
                    )
                }
            }
            
            // Edit button
            Button {
                viewModel.showingFinancing = true
            } label: {
                Text("Edit Assumptions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary)
                    .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Market Section
    
    private var marketSection: some View {
        VStack(spacing: 24) {
            ModernSection(title: "Market Indicators", background: cardBackground) {
                VStack(spacing: 0) {
                    ModernMarketRow(title: "Rent Growth", indicator: viewModel.metrics.marketSupport.rentGrowth)
                    Divider().padding(.leading, 16)
                    ModernMarketRow(title: "Price Appreciation", indicator: viewModel.metrics.marketSupport.priceAppreciation)
                    Divider().padding(.leading, 16)
                    ModernMarketRow(title: "Vacancy Rate", indicator: viewModel.metrics.marketSupport.vacancyTrend)
                    Divider().padding(.leading, 16)
                    ModernMarketRow(title: "Days on Market", indicator: viewModel.metrics.marketSupport.daysOnMarket)
                    Divider().padding(.leading, 16)
                    ModernMarketRow(title: "Housing Supply", indicator: viewModel.metrics.marketSupport.supplyTrend)
                    Divider().padding(.leading, 16)
                    ModernMarketRow(title: "Demand", indicator: viewModel.metrics.marketSupport.demandIndicator)
                }
            }
            
            // Refresh button
            Button {
                Task {
                    await viewModel.fetchAllData()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isFetchingData {
                        ProgressView()
                            .tint(colorScheme == .dark ? Color.black : Color.white)
                    }
                    Text(viewModel.isFetchingData ? "Refreshing..." : "Refresh Market Data")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primary)
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(viewModel.isFetchingData)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Risk Section
    
    private var riskSection: some View {
        VStack(spacing: 24) {
            // Break-even
            ModernSection(title: "Break-Even Analysis", background: cardBackground) {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Break-Even Occupancy")
                                .font(.subheadline)
                            Text("Minimum occupancy to cover all costs")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        Text(viewModel.metrics.riskBuffers.breakEvenOccupancy.asPercent())
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(viewModel.metrics.riskBuffers.breakEvenOccupancy <= 0.85 ? .green : .orange)
                    }
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.1))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewModel.metrics.riskBuffers.breakEvenOccupancy <= 0.85 ? Color.green : Color.orange)
                                .frame(width: geo.size.width * min(viewModel.metrics.riskBuffers.breakEvenOccupancy, 1.0))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(16)
            }
            
            // Sensitivity
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sensitivity Analysis")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        viewModel.showingSensitivity = true
                    } label: {
                        Text("Details")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 0) {
                    SensitivityRow(result: viewModel.metrics.riskBuffers.sensitivityAnalysis.rentUp10, baseValue: viewModel.metrics.dealEconomics.annualCashFlow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    Divider().padding(.leading, 16)
                    SensitivityRow(result: viewModel.metrics.riskBuffers.sensitivityAnalysis.rentDown10, baseValue: viewModel.metrics.dealEconomics.annualCashFlow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    Divider().padding(.leading, 16)
                    SensitivityRow(result: viewModel.metrics.riskBuffers.sensitivityAnalysis.rateUp1, baseValue: viewModel.metrics.dealEconomics.annualCashFlow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    Divider().padding(.leading, 16)
                    SensitivityRow(result: viewModel.metrics.riskBuffers.sensitivityAnalysis.rateDown1, baseValue: viewModel.metrics.dealEconomics.annualCashFlow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            }
            
            // Stress test
            ModernSection(title: "Stress Test", background: cardBackground) {
                VStack(spacing: 16) {
                    ModernStressRow(
                        title: "Worst Case Cash Flow",
                        subtitle: "Rent -10%, Vacancy +5%, Expenses +10%",
                        value: viewModel.metrics.riskBuffers.stressTestResults.worstCaseCashFlow.asCurrency,
                        isPositive: viewModel.metrics.riskBuffers.stressTestResults.worstCaseCashFlow >= 0
                    )
                    
                    Divider()
                    
                    ModernStressRow(
                        title: "Max Vacancy Before Negative",
                        subtitle: "Occupancy can drop to",
                        value: (1 - viewModel.metrics.riskBuffers.stressTestResults.maxVacancyBeforeNegative).asPercent(),
                        isPositive: viewModel.metrics.riskBuffers.stressTestResults.maxVacancyBeforeNegative >= 0.15
                    )
                    
                    Divider()
                    
                    ModernStressRow(
                        title: "Max Rate Before Negative",
                        subtitle: "Rate can increase to",
                        value: viewModel.metrics.riskBuffers.stressTestResults.maxRateBeforeNegative.asPercent(),
                        isPositive: viewModel.metrics.riskBuffers.stressTestResults.maxRateBeforeNegative >= viewModel.property.financing.interestRate + 0.02
                    )
                }
                .padding(16)
            }
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        NotesView(propertyID: viewModel.property.id)
            .padding(.horizontal, 20)
    }
}

// MARK: - Modern Components

struct QuickStat: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.body, design: .rounded, weight: .semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ModernScoreBadge: View {
    let score: Double
    let recommendation: InvestmentRecommendation
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 4)
                .frame(width: 64, height: 64)
            
            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(recommendation.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 0) {
                Text("\(Int(score))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
        }
    }
}

struct HeroMetricCard: View {
    let title: String
    let value: String
    let isPositive: Bool
    let background: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ModernMetricRow: View {
    let metric: ScoredMetric
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name)
                    .font(.subheadline)
                
                Text("Target: \(metric.displayThreshold)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(metric.displayValue)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(metric.score.color)
                
                Circle()
                    .fill(metric.score.color.opacity(0.15))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: metric.score.icon)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(metric.score.color)
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

struct ModernSection<Content: View>: View {
    let title: String
    let background: Color
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            content()
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
        }
    }
}

struct ModernEconomicsRow: View {
    let title: String
    let value: String
    var valueColor: Color? = nil
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(isHighlighted ? .medium : .regular)
            
            Spacer()
            
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: isHighlighted ? .semibold : .medium))
                .foregroundStyle(valueColor ?? .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHighlighted ? Color.primary.opacity(0.03) : Color.clear)
    }
}

struct ModernMarketRow: View {
    let title: String
    let indicator: MarketIndicator
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                
                Text(indicator.description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(indicator.displayValue)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                
                HStack(spacing: 4) {
                    Image(systemName: indicator.trend.rawValue)
                        .font(.caption2)
                    
                    Text(indicator.signal.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundStyle(indicator.signal.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(indicator.signal.color.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ModernStressRow: View {
    let title: String
    let subtitle: String
    let value: String
    let isPositive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(isPositive ? .green : .red)
        }
    }
}

// MARK: - Stat Pill (kept for compatibility)

struct StatPill: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Section Header (kept for compatibility)

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
            Text(title)
                .font(.headline)
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Economics Row (kept for compatibility)

struct EconomicsRow: View {
    let title: String
    let value: String
    var isTotal: Bool = false
    var color: Color? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(isTotal ? .subheadline.weight(.medium) : .subheadline)
            
            Spacer()
            
            Text(value)
                .font(.system(isTotal ? .subheadline : .subheadline, design: .rounded, weight: isTotal ? .semibold : .regular))
                .foregroundStyle(color ?? .primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(isTotal ? Color(.systemGray6) : .clear)
    }
}

struct StressTestRow: View {
    let title: String
    let subtitle: String
    let value: String
    let isPositive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(isPositive ? .green : .red)
        }
    }
}

// MARK: - Financing Sheet

struct FinancingSheet: View {
    @Bindable var viewModel: PropertyDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Rent
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Income")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        CurrencyField(title: "Monthly Rent (per unit)", value: $viewModel.property.estimatedRentPerUnit)
                            .onChange(of: viewModel.property.estimatedRentPerUnit) { _, newValue in
                                viewModel.property.estimatedTotalRent = newValue * Double(viewModel.property.unitCount)
                            }
                        
                        SliderField(
                            title: "Vacancy Rate",
                            value: $viewModel.property.vacancyRate,
                            range: 0...0.20,
                            step: 0.01,
                            format: .percent
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Financing
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Financing")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        CurrencyField(title: "Purchase Price", value: $viewModel.property.financing.purchasePrice)
                        
                        SliderField(
                            title: "LTV",
                            value: $viewModel.property.financing.ltv,
                            range: 0...0.95,
                            step: 0.05,
                            format: .percent
                        )
                        .onChange(of: viewModel.property.financing.ltv) { _, _ in
                            viewModel.property.financing.updateLoanFromLTV()
                        }
                        
                        PercentField(title: "Interest Rate", value: $viewModel.property.financing.interestRate)
                    }
                    .padding(.horizontal, 20)
                    
                    // Expenses
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Expenses")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        CurrencyField(title: "Annual Taxes", value: $viewModel.property.annualTaxes)
                        CurrencyField(title: "Annual Insurance", value: $viewModel.property.insuranceAnnual)
                        
                        SliderField(
                            title: "Management Fee",
                            value: $viewModel.property.managementFeePercent,
                            range: 0...0.15,
                            step: 0.01,
                            format: .percent
                        )
                        
                        CurrencyField(title: "Repairs (per unit/year)", value: $viewModel.property.repairsPerUnit)
                    }
                    .padding(.horizontal, 20)
                    
                    // Thresholds
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Target Thresholds")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        PercentField(title: "Target Cap Rate", value: $viewModel.property.thresholds.targetCapRate)
                        PercentField(title: "Target Cash-on-Cash", value: $viewModel.property.thresholds.targetCashOnCash)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Target DSCR")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                TextField("1.25", value: $viewModel.property.thresholds.targetDSCR, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                
                                Text("x")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Edit Assumptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Sensitivity Sheet

struct SensitivitySheet: View {
    let metrics: DealMetrics
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Base case
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Base Case")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text("Annual Cash Flow")
                                .font(.subheadline)
                            Spacer()
                            Text(metrics.dealEconomics.annualCashFlow.asCurrency)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .padding(16)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    
                    // Rent sensitivity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rent Sensitivity")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 0) {
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.rentUp10)
                            Divider().padding(.leading, 16)
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.rentDown10)
                        }
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    
                    // Rate sensitivity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rate Sensitivity")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 0) {
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.rateUp1)
                            Divider().padding(.leading, 16)
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.rateDown1)
                        }
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    
                    // Exit cap sensitivity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exit Cap Sensitivity")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 0) {
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.exitCapUp50bps)
                            Divider().padding(.leading, 16)
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.exitCapDown50bps)
                        }
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Sensitivity Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct SensitivityDetailRow: View {
    let result: SensitivityResult
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(result.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: result.deltaFromBase >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(abs(result.deltaFromBase).asCurrency)
                        .font(.caption)
                }
                .foregroundStyle(result.deltaFromBase >= 0 ? .green : .red)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cash Flow")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(result.cashFlow.asCurrency)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("CoC")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(result.cashOnCash.asPercent())
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("DSCR")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(String(format: "%.2fx", result.dscr))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PropertyDetailView(property: .preview, onSave: { _ in })
    }
}
