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
    
    init(property: Property, onSave: @escaping (Property) async -> Void) {
        _viewModel = State(initialValue: PropertyDetailViewModel(property: property, onSave: onSave))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                propertyHeader
                
                // Section picker
                sectionPicker
                    .padding(.top)
                
                // Content based on section
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
                .padding(.top)
            }
        }
        .background(Color(.systemGroupedBackground))
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
                        Label("Edit Financing", systemImage: "banknote")
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
            // Photo
            ZStack(alignment: .bottom) {
                if let photoData = viewModel.property.primaryPhotoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 200)
                        .overlay {
                            Image(systemName: viewModel.property.propertyType.icon)
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                        }
                }
                
                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                
                // Score badge
                HStack {
                    ScoreBadge(
                        score: viewModel.metrics.overallScore,
                        recommendation: viewModel.metrics.recommendation
                    )
                    
                    Spacer()
                    
                    Text(viewModel.property.askingPrice.asCompactCurrency)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .padding()
            }
            
            // Address
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.property.address)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("\(viewModel.property.city), \(viewModel.property.state) \(viewModel.property.zipCode)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Quick stats
                HStack(spacing: 16) {
                    StatPill(icon: "bed.double.fill", value: "\(viewModel.property.bedrooms) bed")
                    StatPill(icon: "shower.fill", value: String(format: "%.1f bath", viewModel.property.bathrooms))
                    StatPill(icon: "square.fill", value: "\(viewModel.property.squareFeet.withCommas) sqft")
                    StatPill(icon: "calendar", value: "\(viewModel.property.yearBuilt)")
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
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
                        HStack(spacing: 4) {
                            Image(systemName: section.icon)
                                .font(.caption)
                            
                            Text(section.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.activeSection == section
                            ? Color.accentColor
                            : Color(.systemGray5)
                        )
                        .foregroundStyle(
                            viewModel.activeSection == section
                            ? .white
                            : .primary
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: 16) {
            // Key metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                LargeMetricCard(
                    title: "Monthly Cash Flow",
                    value: viewModel.metrics.dealEconomics.monthlyCashFlow.asCurrency,
                    trend: viewModel.metrics.dealEconomics.monthlyCashFlow >= 0 ? .up : .down,
                    trendValue: nil,
                    color: viewModel.metrics.dealEconomics.monthlyCashFlow >= 0 ? .green : .red
                )
                
                LargeMetricCard(
                    title: "Cap Rate",
                    value: viewModel.metrics.dealEconomics.inPlaceCapRate.asPercent(),
                    trend: nil,
                    trendValue: nil,
                    color: viewModel.metrics.dealEconomics.inPlaceCapRate >= viewModel.property.thresholds.targetCapRate ? .green : .orange
                )
            }
            .padding(.horizontal)
            
            // All scored metrics
            VStack(alignment: .leading, spacing: 8) {
                Text("Metrics Scorecard")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    ForEach(viewModel.metrics.scoredMetrics) { metric in
                        MetricRow(metric: metric)
                            .padding(.horizontal)
                        
                        if metric.id != viewModel.metrics.scoredMetrics.last?.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
            }
            
            // Recommendation
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendation")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack {
                    Image(systemName: viewModel.metrics.recommendation.icon)
                        .font(.title2)
                        .foregroundStyle(viewModel.metrics.recommendation.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.metrics.recommendation.rawValue)
                            .font(.headline)
                            .foregroundStyle(viewModel.metrics.recommendation.color)
                        
                        Text(viewModel.metrics.recommendation.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    // MARK: - Economics Section
    
    private var economicsSection: some View {
        VStack(spacing: 16) {
            // Income
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Income", icon: "arrow.up.circle.fill")
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    EconomicsRow(title: "Gross Potential Rent", value: viewModel.metrics.dealEconomics.grossPotentialRent.asCurrency)
                    Divider().padding(.leading)
                    EconomicsRow(title: "Vacancy Loss", value: "(\(viewModel.metrics.dealEconomics.vacancyLoss.asCurrency))", color: .red)
                    Divider().padding(.leading)
                    EconomicsRow(title: "Effective Gross Income", value: viewModel.metrics.dealEconomics.effectiveGrossIncome.asCurrency, isTotal: true)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
            }
            
            // Expenses
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Operating Expenses", icon: "arrow.down.circle.fill")
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    EconomicsRow(title: "Property Taxes", value: viewModel.metrics.dealEconomics.expenseBreakdown.taxes.asCurrency)
                    Divider().padding(.leading)
                    EconomicsRow(title: "Insurance", value: viewModel.metrics.dealEconomics.expenseBreakdown.insurance.asCurrency)
                    Divider().padding(.leading)
                    EconomicsRow(title: "Management", value: viewModel.metrics.dealEconomics.expenseBreakdown.management.asCurrency)
                    Divider().padding(.leading)
                    EconomicsRow(title: "Repairs/Maintenance", value: viewModel.metrics.dealEconomics.expenseBreakdown.repairs.asCurrency)
                    Divider().padding(.leading)
                    EconomicsRow(title: "CapEx Reserve", value: viewModel.metrics.dealEconomics.expenseBreakdown.capexReserve.asCurrency)
                    Divider().padding(.leading)
                    EconomicsRow(title: "Other", value: viewModel.metrics.dealEconomics.expenseBreakdown.other.asCurrency)
                    Divider().padding(.leading)
                    EconomicsRow(title: "Total Expenses", value: viewModel.metrics.dealEconomics.totalOperatingExpenses.asCurrency, isTotal: true)
                    Divider().padding(.leading)
                    EconomicsRow(title: "Expense Ratio", value: viewModel.metrics.dealEconomics.expenseBreakdown.expenseRatio.asPercent(), isTotal: true)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
            }
            
            // NOI & Returns
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Returns", icon: "chart.line.uptrend.xyaxis")
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    EconomicsRow(title: "Net Operating Income (NOI)", value: viewModel.metrics.dealEconomics.netOperatingIncome.asCurrency, isTotal: true)
                    Divider().padding(.leading)
                    EconomicsRow(title: "Annual Debt Service", value: "(\(viewModel.metrics.dealEconomics.annualDebtService.asCurrency))")
                    Divider().padding(.leading)
                    EconomicsRow(title: "Annual Cash Flow", value: viewModel.metrics.dealEconomics.annualCashFlow.asCurrency, isTotal: true, color: viewModel.metrics.dealEconomics.annualCashFlow >= 0 ? .green : .red)
                    Divider().padding(.leading)
                    EconomicsRow(title: "Monthly Cash Flow", value: viewModel.metrics.dealEconomics.monthlyCashFlow.asCurrency, color: viewModel.metrics.dealEconomics.monthlyCashFlow >= 0 ? .green : .red)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
            }
            
            // Edit rent button
            Button {
                viewModel.showingFinancing = true
            } label: {
                Label("Edit Assumptions", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    // MARK: - Market Section
    
    private var marketSection: some View {
        VStack(spacing: 16) {
            // Market indicators
            VStack(alignment: .leading, spacing: 8) {
                Text("Market Indicators")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    MarketIndicatorRow(title: "Rent Growth", indicator: viewModel.metrics.marketSupport.rentGrowth)
                        .padding(.horizontal)
                    Divider().padding(.leading)
                    MarketIndicatorRow(title: "Price Appreciation", indicator: viewModel.metrics.marketSupport.priceAppreciation)
                        .padding(.horizontal)
                    Divider().padding(.leading)
                    MarketIndicatorRow(title: "Vacancy Rate", indicator: viewModel.metrics.marketSupport.vacancyTrend)
                        .padding(.horizontal)
                    Divider().padding(.leading)
                    MarketIndicatorRow(title: "Days on Market", indicator: viewModel.metrics.marketSupport.daysOnMarket)
                        .padding(.horizontal)
                    Divider().padding(.leading)
                    MarketIndicatorRow(title: "Housing Supply", indicator: viewModel.metrics.marketSupport.supplyTrend)
                        .padding(.horizontal)
                    Divider().padding(.leading)
                    MarketIndicatorRow(title: "Demand", indicator: viewModel.metrics.marketSupport.demandIndicator)
                        .padding(.horizontal)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
            }
            
            // Refresh button
            Button {
                Task {
                    await viewModel.fetchAllData()
                }
            } label: {
                Label(viewModel.isFetchingData ? "Refreshing..." : "Refresh Market Data", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isFetchingData)
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    // MARK: - Risk Section
    
    private var riskSection: some View {
        VStack(spacing: 16) {
            // Break-even
            VStack(alignment: .leading, spacing: 8) {
                Text("Break-Even Analysis")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Break-Even Occupancy")
                                .font(.subheadline)
                            Text("Minimum occupancy to cover expenses + debt")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        Text(viewModel.metrics.riskBuffers.breakEvenOccupancy.asPercent())
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(viewModel.metrics.riskBuffers.breakEvenOccupancy <= 0.85 ? .green : .orange)
                    }
                    
                    // Visual gauge
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewModel.metrics.riskBuffers.breakEvenOccupancy <= 0.85 ? Color.green : Color.orange)
                                .frame(width: geo.size.width * min(viewModel.metrics.riskBuffers.breakEvenOccupancy, 1.0))
                        }
                    }
                    .frame(height: 8)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
            }
            
            // Sensitivity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sensitivity Analysis")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        viewModel.showingSensitivity = true
                    } label: {
                        Text("Details")
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
                
                VStack(spacing: 0) {
                    SensitivityRow(result: viewModel.metrics.riskBuffers.sensitivityAnalysis.rentUp10, baseValue: viewModel.metrics.dealEconomics.annualCashFlow)
                        .padding(.horizontal)
                    Divider().padding(.leading)
                    SensitivityRow(result: viewModel.metrics.riskBuffers.sensitivityAnalysis.rentDown10, baseValue: viewModel.metrics.dealEconomics.annualCashFlow)
                        .padding(.horizontal)
                    Divider().padding(.leading)
                    SensitivityRow(result: viewModel.metrics.riskBuffers.sensitivityAnalysis.rateUp1, baseValue: viewModel.metrics.dealEconomics.annualCashFlow)
                        .padding(.horizontal)
                    Divider().padding(.leading)
                    SensitivityRow(result: viewModel.metrics.riskBuffers.sensitivityAnalysis.rateDown1, baseValue: viewModel.metrics.dealEconomics.annualCashFlow)
                        .padding(.horizontal)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
            }
            
            // Stress test
            VStack(alignment: .leading, spacing: 8) {
                Text("Stress Test")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    StressTestRow(
                        title: "Worst Case Cash Flow",
                        subtitle: "Rent -10%, Vacancy +5%, Expenses +10%",
                        value: viewModel.metrics.riskBuffers.stressTestResults.worstCaseCashFlow.asCurrency,
                        isPositive: viewModel.metrics.riskBuffers.stressTestResults.worstCaseCashFlow >= 0
                    )
                    
                    Divider()
                    
                    StressTestRow(
                        title: "Max Vacancy Before Negative",
                        subtitle: "Occupancy can drop to",
                        value: (1 - viewModel.metrics.riskBuffers.stressTestResults.maxVacancyBeforeNegative).asPercent(),
                        isPositive: viewModel.metrics.riskBuffers.stressTestResults.maxVacancyBeforeNegative >= 0.15
                    )
                    
                    Divider()
                    
                    StressTestRow(
                        title: "Max Rate Before Negative",
                        subtitle: "Rate can increase to",
                        value: viewModel.metrics.riskBuffers.stressTestResults.maxRateBeforeNegative.asPercent(),
                        isPositive: viewModel.metrics.riskBuffers.stressTestResults.maxRateBeforeNegative >= viewModel.property.financing.interestRate + 0.02
                    )
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        NotesView(propertyID: viewModel.property.id)
            .padding(.horizontal)
    }
}

// MARK: - Supporting Views

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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Rent
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Income", icon: "arrow.up.circle.fill")
                        
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
                    .padding(.horizontal)
                    
                    // Financing
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Financing", icon: "banknote.fill")
                        
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
                    .padding(.horizontal)
                    
                    // Expenses
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Expenses", icon: "arrow.down.circle.fill")
                        
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
                    .padding(.horizontal)
                    
                    // Thresholds
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Target Thresholds", icon: "target")
                        
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
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Edit Assumptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Sensitivity Sheet

struct SensitivitySheet: View {
    let metrics: DealMetrics
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Base case
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base Case")
                            .font(.headline)
                        
                        HStack {
                            Text("Annual Cash Flow")
                            Spacer()
                            Text(metrics.dealEconomics.annualCashFlow.asCurrency)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.horizontal)
                    
                    // Rent sensitivity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rent Sensitivity")
                            .font(.headline)
                        
                        VStack(spacing: 0) {
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.rentUp10)
                            Divider()
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.rentDown10)
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.horizontal)
                    
                    // Rate sensitivity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rate Sensitivity")
                            .font(.headline)
                        
                        VStack(spacing: 0) {
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.rateUp1)
                            Divider()
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.rateDown1)
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.horizontal)
                    
                    // Exit cap sensitivity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exit Cap Sensitivity (Valuation)")
                            .font(.headline)
                        
                        VStack(spacing: 0) {
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.exitCapUp50bps)
                            Divider()
                            SensitivityDetailRow(result: metrics.riskBuffers.sensitivityAnalysis.exitCapDown50bps)
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Sensitivity Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SensitivityDetailRow: View {
    let result: SensitivityResult
    
    var body: some View {
        VStack(spacing: 8) {
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
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(result.cashFlow.asCurrency)
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("CoC")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(result.cashOnCash.asPercent())
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("DSCR")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(String(format: "%.2fx", result.dscr))
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PropertyDetailView(property: .preview, onSave: { _ in })
    }
}
