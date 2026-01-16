//
//  PropertyDetailView.swift
//  Dock
//
//  Property detail with all underwriting metrics
//

import SwiftUI

struct PropertyDetailView: View {
    @State private var viewModel: PropertyDetailViewModel
    @State private var showingDealOptimizer: Bool = false
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
    
    private struct CapexReserveDetails {
        let baseReserve: Double
        let ageMultiplier: Double
    }
    
    private var purchasePriceUsed: Double {
        let financing = viewModel.property.financing
        return financing.purchasePrice > 0 ? financing.purchasePrice : viewModel.property.askingPrice
    }
    
    private var loanAmountUsed: Double {
        let financing = viewModel.property.financing
        return financing.loanAmount > 0 ? financing.loanAmount : purchasePriceUsed * financing.ltv
    }
    
    private var totalCashRequiredUsed: Double {
        let financing = viewModel.property.financing
        let totalCash = financing.totalCashRequired
        if totalCash > 0 {
            return totalCash
        }
        return (purchasePriceUsed - loanAmountUsed) + financing.closingCosts
    }
    
    private var monthlyRentUsed: Double {
        let property = viewModel.property
        return property.estimatedTotalRent > 0
        ? property.estimatedTotalRent
        : property.estimatedRentPerUnit * Double(property.unitCount)
    }
    
    private var capexReserveDetails: CapexReserveDetails {
        let age = Calendar.current.component(.year, from: Date()) - viewModel.property.yearBuilt
        let baseReserve: Double = 300
        let ageMultiplier: Double = {
            switch age {
            case 0...10: return 0.75
            case 11...20: return 1.0
            case 21...30: return 1.25
            case 31...50: return 1.5
            default: return 2.0
            }
        }()
        return CapexReserveDetails(baseReserve: baseReserve, ageMultiplier: ageMultiplier)
    }
    
    private func calculationDetail(title: String, equation: String, variables: [(String, String)]) -> CalculationDetail {
        CalculationDetail(
            title: title,
            equation: equation,
            variables: variables.map { CalculationVariable(name: $0.0, value: $0.1) }
        )
    }
    
    private func metricDetail(for metric: ScoredMetric) -> CalculationDetail? {
        let economics = viewModel.metrics.dealEconomics
        let risk = viewModel.metrics.riskBuffers
        let downPayment = max(purchasePriceUsed - loanAmountUsed, 0)
        let fixedCosts = economics.expenseBreakdown.taxes
        + economics.expenseBreakdown.insurance
        + economics.annualDebtService
        let variableCostPercent = economics.expenseBreakdown.management / max(economics.effectiveGrossIncome, 1)
        
        switch metric.name {
        case "Cap Rate":
            return calculationDetail(
                title: "Cap Rate",
                equation: "Cap Rate = NOI / Purchase Price",
                variables: [
                    ("NOI", economics.netOperatingIncome.asCurrency),
                    ("Purchase Price", purchasePriceUsed.asCurrency),
                    ("Cap Rate", economics.inPlaceCapRate.asPercent())
                ]
            )
        case "Cash-on-Cash":
            return calculationDetail(
                title: "Cash-on-Cash",
                equation: "Cash-on-Cash = Annual Cash Flow / Total Cash Required",
                variables: [
                    ("Annual Cash Flow", economics.annualCashFlow.asCurrency),
                    ("Down Payment", downPayment.asCurrency),
                    ("Closing Costs", viewModel.property.financing.closingCosts.asCurrency),
                    ("Total Cash Required", totalCashRequiredUsed.asCurrency),
                    ("Cash-on-Cash", economics.cashOnCashReturn.asPercent())
                ]
            )
        case "DSCR":
            return calculationDetail(
                title: "DSCR",
                equation: "DSCR = NOI / Annual Debt Service",
                variables: [
                    ("NOI", economics.netOperatingIncome.asCurrency),
                    ("Annual Debt Service", economics.annualDebtService.asCurrency),
                    ("DSCR", String(format: "%.2fx", economics.dscr))
                ]
            )
        case "NOI":
            return calculationDetail(
                title: "NOI",
                equation: "NOI = EGI - Total Operating Expenses",
                variables: [
                    ("EGI", economics.effectiveGrossIncome.asCurrency),
                    ("Total Expenses", economics.totalOperatingExpenses.asCurrency),
                    ("NOI", economics.netOperatingIncome.asCurrency)
                ]
            )
        case "Break-even Occupancy":
            return calculationDetail(
                title: "Break-even Occupancy",
                equation: "Break-even = Fixed Costs / (GPR × (1 - Variable Costs %))",
                variables: [
                    ("Fixed Costs", fixedCosts.asCurrency),
                    ("GPR", economics.grossPotentialRent.asCurrency),
                    ("Variable Costs %", variableCostPercent.asPercent()),
                    ("Break-even", risk.breakEvenOccupancy.asPercent())
                ]
            )
        case "Worst Case Cash Flow":
            return calculationDetail(
                title: "Worst Case Cash Flow",
                equation: "Worst Case = Rent -10%, Vacancy +5%, Repairs +10%",
                variables: [
                    ("Assumed Rent", (monthlyRentUsed * 0.90).asCurrency),
                    ("Vacancy Rate", min(viewModel.property.vacancyRate + 0.05, 0.25).asPercent()),
                    ("Repairs per Unit", (viewModel.property.repairsPerUnit * 1.10).asCurrency),
                    ("Annual Cash Flow", risk.stressTestResults.worstCaseCashFlow.asCurrency)
                ]
            )
        default:
            return calculationDetail(
                title: metric.name,
                equation: "Market data (no internal calculation)",
                variables: [
                    ("Value", metric.displayValue),
                    ("Source", "Market data")
                ]
            )
        }
    }
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 100, height: 100)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
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
                        case .checklist:
                            ChecklistSectionView(viewModel: viewModel)
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
        .sheet(isPresented: $showingDealOptimizer) {
            DealOptimizerSheet(viewModel: viewModel)
        }
    }
    
    // MARK: - Property Header
    
    @ViewBuilder
    private var propertyThumbnail: some View {
        if let photoData = viewModel.property.primaryPhotoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let firstURL = viewModel.property.photoURLs.first,
                  let url = URL(string: firstURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                case .failure:
                    placeholderImage
                case .empty:
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 100, height: 100)
                        .overlay {
                            ProgressView()
                        }
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }
    
    private var propertyHeader: some View {
        VStack(spacing: 0) {
            // Property info with image
            VStack(alignment: .leading, spacing: 16) {
                // Image + Price/Address row
                HStack(alignment: .top, spacing: 16) {
                    // Small square image
                    propertyThumbnail
                    
                    // Price and address
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.property.askingPrice.asCompactCurrency)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        
                        Text(viewModel.property.address)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        
                        Text("\(viewModel.property.city), \(viewModel.property.state) \(viewModel.property.zipCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // View Listing Link
                        if let url = viewModel.property.viewableListingURL {
                            Button {
                                openURL(url)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption2)
                                    Text("View on \(viewModel.property.listingSource ?? "Zillow")")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                
                // Quick stats
                HStack(spacing: 0) {
                    QuickStat(value: "\(viewModel.property.bedrooms)", label: "Beds")
                    
                    Divider()
                        .frame(height: 32)
                        .padding(.horizontal, 12)
                    
                    QuickStat(value: String(format: "%.1f", viewModel.property.bathrooms), label: "Baths")
                    
                    Divider()
                        .frame(height: 32)
                        .padding(.horizontal, 12)
                    
                    QuickStat(value: viewModel.property.squareFeet.withCommas, label: "Sq Ft")
                    
                    Divider()
                        .frame(height: 32)
                        .padding(.horizontal, 12)
                    
                    QuickStat(value: "\(viewModel.property.yearBuilt)", label: "Built")
                    
                    Spacer()
                }
                .padding(.top, 4)
                
                // Horizontal score gauge
                HorizontalScoreGauge(
                    score: viewModel.metrics.overallScore,
                    recommendation: viewModel.metrics.recommendation
                )
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
                        ModernMetricRow(metric: metric, detail: metricDetail(for: metric))
                        
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
            
            // Deal Optimizer button
            Button {
                showingDealOptimizer = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.below.square.and.square.filled")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deal Optimizer")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Find your ideal purchase price")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Economics Section
    @ViewBuilder
    private var economicsSection: some View {
        let economics = viewModel.metrics.dealEconomics
        let monthlyRent = monthlyRentUsed
        let capexDetails = capexReserveDetails
        
        VStack(spacing: 24) {
            // Income
            ModernSection(title: "Income", background: cardBackground) {
                VStack(spacing: 0) {
                    ModernEconomicsRow(
                        title: "Gross Potential Rent",
                        value: economics.grossPotentialRent.asCurrency,
                        detail: calculationDetail(
                            title: "Gross Potential Rent",
                            equation: "GPR = Monthly Rent × 12",
                            variables: [
                                ("Monthly Rent", monthlyRent.asCurrency),
                                ("Annualization", "12 months"),
                                ("GPR", economics.grossPotentialRent.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Vacancy Loss",
                        value: "-\(economics.vacancyLoss.asCurrency)",
                        valueColor: .red.opacity(0.8),
                        detail: calculationDetail(
                            title: "Vacancy Loss",
                            equation: "Vacancy Loss = GPR × Vacancy Rate",
                            variables: [
                                ("GPR", economics.grossPotentialRent.asCurrency),
                                ("Vacancy Rate", viewModel.property.vacancyRate.asPercent()),
                                ("Vacancy Loss", economics.vacancyLoss.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Effective Gross Income",
                        value: economics.effectiveGrossIncome.asCurrency,
                        isHighlighted: true,
                        detail: calculationDetail(
                            title: "Effective Gross Income",
                            equation: "EGI = GPR - Vacancy Loss",
                            variables: [
                                ("GPR", economics.grossPotentialRent.asCurrency),
                                ("Vacancy Loss", economics.vacancyLoss.asCurrency),
                                ("EGI", economics.effectiveGrossIncome.asCurrency)
                            ]
                        )
                    )
                }
            }
            
            // Expenses
            ModernSection(title: "Operating Expenses", background: cardBackground) {
                VStack(spacing: 0) {
                    ModernEconomicsRow(
                        title: "Property Taxes",
                        value: economics.expenseBreakdown.taxes.asCurrency,
                        detail: calculationDetail(
                            title: "Property Taxes",
                            equation: "Property Taxes = Annual Taxes (input)",
                            variables: [
                                ("Annual Taxes", viewModel.property.annualTaxes.asCurrency),
                                ("Property Taxes", economics.expenseBreakdown.taxes.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Insurance",
                        value: economics.expenseBreakdown.insurance.asCurrency,
                        detail: calculationDetail(
                            title: "Insurance",
                            equation: "Insurance = Annual Insurance (input/estimate)",
                            variables: [
                                ("Annual Insurance", viewModel.property.insuranceAnnual.asCurrency),
                                ("Insurance", economics.expenseBreakdown.insurance.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Management",
                        value: economics.expenseBreakdown.management.asCurrency,
                        detail: calculationDetail(
                            title: "Management",
                            equation: "Management = EGI × Management Fee %",
                            variables: [
                                ("EGI", economics.effectiveGrossIncome.asCurrency),
                                ("Management Fee %", viewModel.property.managementFeePercent.asPercent()),
                                ("Management", economics.expenseBreakdown.management.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Repairs/Maintenance",
                        value: economics.expenseBreakdown.repairs.asCurrency,
                        detail: calculationDetail(
                            title: "Repairs/Maintenance",
                            equation: "Repairs = Repairs per Unit × Units",
                            variables: [
                                ("Repairs per Unit", viewModel.property.repairsPerUnit.asCurrency),
                                ("Units", "\(viewModel.property.unitCount)"),
                                ("Repairs", economics.expenseBreakdown.repairs.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "CapEx Reserve",
                        value: economics.expenseBreakdown.capexReserve.asCurrency,
                        detail: calculationDetail(
                            title: "CapEx Reserve",
                            equation: "CapEx = Base Reserve × Age Multiplier × Units",
                            variables: [
                                ("Base Reserve", capexDetails.baseReserve.asCurrency),
                                ("Age Multiplier", capexDetails.ageMultiplier.formatted(decimals: 2) + "x"),
                                ("Units", "\(viewModel.property.unitCount)"),
                                ("CapEx", economics.expenseBreakdown.capexReserve.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Other",
                        value: economics.expenseBreakdown.other.asCurrency,
                        detail: calculationDetail(
                            title: "Other Expenses",
                            equation: "Other = Other Expenses (input)",
                            variables: [
                                ("Other Expenses", viewModel.property.otherExpenses.asCurrency),
                                ("Other", economics.expenseBreakdown.other.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Total Expenses",
                        value: economics.totalOperatingExpenses.asCurrency,
                        isHighlighted: true,
                        detail: calculationDetail(
                            title: "Total Expenses",
                            equation: "Total = Taxes + Insurance + Management + Repairs + CapEx + Utilities + Other",
                            variables: [
                                ("Taxes", economics.expenseBreakdown.taxes.asCurrency),
                                ("Insurance", economics.expenseBreakdown.insurance.asCurrency),
                                ("Management", economics.expenseBreakdown.management.asCurrency),
                                ("Repairs", economics.expenseBreakdown.repairs.asCurrency),
                                ("CapEx", economics.expenseBreakdown.capexReserve.asCurrency),
                                ("Utilities", economics.expenseBreakdown.utilities.asCurrency),
                                ("Other", economics.expenseBreakdown.other.asCurrency),
                                ("Total", economics.totalOperatingExpenses.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Expense Ratio",
                        value: economics.expenseBreakdown.expenseRatio.asPercent(),
                        isHighlighted: true,
                        detail: calculationDetail(
                            title: "Expense Ratio",
                            equation: "Expense Ratio = Total Expenses / EGI",
                            variables: [
                                ("Total Expenses", economics.totalOperatingExpenses.asCurrency),
                                ("EGI", economics.effectiveGrossIncome.asCurrency),
                                ("Expense Ratio", economics.expenseBreakdown.expenseRatio.asPercent())
                            ]
                        )
                    )
                }
            }
            
            // Returns
            ModernSection(title: "Returns", background: cardBackground) {
                VStack(spacing: 0) {
                    ModernEconomicsRow(
                        title: "Net Operating Income",
                        value: economics.netOperatingIncome.asCurrency,
                        isHighlighted: true,
                        detail: calculationDetail(
                            title: "Net Operating Income",
                            equation: "NOI = EGI - Total Operating Expenses",
                            variables: [
                                ("EGI", economics.effectiveGrossIncome.asCurrency),
                                ("Total Expenses", economics.totalOperatingExpenses.asCurrency),
                                ("NOI", economics.netOperatingIncome.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Annual Debt Service",
                        value: "-\(economics.annualDebtService.asCurrency)",
                        detail: calculationDetail(
                            title: "Annual Debt Service",
                            equation: "Annual Debt Service = Monthly Debt Service × 12",
                            variables: [
                                ("Monthly Debt Service", economics.monthlyDebtService.asCurrency),
                                ("Annualization", "12 months"),
                                ("Annual Debt Service", economics.annualDebtService.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Annual Cash Flow",
                        value: economics.annualCashFlow.asCurrency,
                        isPositiveIndicator: economics.annualCashFlow >= 0,
                        isHighlighted: true,
                        detail: calculationDetail(
                            title: "Annual Cash Flow",
                            equation: "Annual Cash Flow = NOI - Annual Debt Service",
                            variables: [
                                ("NOI", economics.netOperatingIncome.asCurrency),
                                ("Annual Debt Service", economics.annualDebtService.asCurrency),
                                ("Annual Cash Flow", economics.annualCashFlow.asCurrency)
                            ]
                        )
                    )
                    Divider().padding(.leading, 16)
                    ModernEconomicsRow(
                        title: "Monthly Cash Flow",
                        value: economics.monthlyCashFlow.asCurrency,
                        isPositiveIndicator: economics.monthlyCashFlow >= 0,
                        detail: calculationDetail(
                            title: "Monthly Cash Flow",
                            equation: "Monthly Cash Flow = Annual Cash Flow ÷ 12",
                            variables: [
                                ("Annual Cash Flow", economics.annualCashFlow.asCurrency),
                                ("Monthly Cash Flow", economics.monthlyCashFlow.asCurrency)
                            ]
                        )
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
                        
                        HStack(spacing: 8) {
                            Text(viewModel.metrics.riskBuffers.breakEvenOccupancy.asPercent())
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Circle()
                                .fill(viewModel.metrics.riskBuffers.breakEvenOccupancy <= 0.85 
                                      ? Color(red: 0.2, green: 0.7, blue: 0.4) 
                                      : Color(red: 1.0, green: 0.6, blue: 0.2))
                                .frame(width: 12, height: 12)
                        }
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

struct HorizontalScoreGauge: View {
    let score: Double
    let recommendation: InvestmentRecommendation
    
    private var gaugeGradient: LinearGradient {
        let baseColor: Color = {
            switch score {
            case 0..<40:
                return Color(red: 0.9, green: 0.3, blue: 0.3)
            case 40..<60:
                return Color(red: 1.0, green: 0.6, blue: 0.2)
            case 60..<75:
                return Color(red: 0.95, green: 0.75, blue: 0.2)
            default:
                return Color(red: 0.2, green: 0.7, blue: 0.4)
            }
        }()
        
        return LinearGradient(
            colors: [baseColor.opacity(0.6), baseColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Score label
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(score))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("/ 100")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Text(recommendation.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(recommendation.color)
            }
            
            // Gauge bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                    
                    // Filled portion
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(gaugeGradient)
                        .frame(width: geo.size.width * (score / 100))
                }
            }
            .frame(height: 10)
        }
    }
}

struct HeroMetricCard: View {
    let title: String
    let value: String
    let isPositive: Bool
    let background: Color
    
    private var statusColor: Color {
        isPositive ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color(red: 0.9, green: 0.3, blue: 0.3)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ModernMetricRow: View {
    let metric: ScoredMetric
    let detail: CalculationDetail?
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
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
                        .foregroundStyle(.primary)
                    
                    Circle()
                        .fill(metric.score.color)
                        .frame(width: 10, height: 10)
                    
                    if detail != nil {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                guard detail != nil else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            if let detail, isExpanded {
                CalculationDetailView(detail: detail)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
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
    var isPositiveIndicator: Bool? = nil
    var isHighlighted: Bool = false
    var detail: CalculationDetail? = nil
    @State private var isExpanded: Bool = false
    
    private var indicatorColor: Color? {
        guard let isPositive = isPositiveIndicator else { return nil }
        return isPositive 
            ? Color(red: 0.2, green: 0.7, blue: 0.4) 
            : Color(red: 0.9, green: 0.3, blue: 0.3)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isHighlighted ? .medium : .regular)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text(value)
                        .font(.system(.subheadline, design: .rounded, weight: isHighlighted ? .semibold : .medium))
                        .foregroundStyle(.primary)
                    
                    if let color = indicatorColor {
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                    }
                    
                    if detail != nil {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isHighlighted ? Color.primary.opacity(0.03) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                guard detail != nil else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            if let detail, isExpanded {
                CalculationDetailView(detail: detail)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }
}

struct CalculationDetail: Identifiable {
    let id = UUID()
    let title: String
    let equation: String
    let variables: [CalculationVariable]
}

struct CalculationVariable: Identifiable {
    let id = UUID()
    let name: String
    let value: String
}

struct CalculationDetailView: View {
    let detail: CalculationDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calculation")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Text(detail.equation)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(detail.variables) { variable in
                HStack {
                    Text(variable.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(variable.value)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    
    private var statusColor: Color {
        isPositive ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color(red: 0.9, green: 0.3, blue: 0.3)
    }
    
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
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
            }
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
    
    private var statusColor: Color {
        isPositive ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color(red: 0.9, green: 0.3, blue: 0.3)
    }
    
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
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
            }
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
    
    private var statusColor: Color {
        result.deltaFromBase >= 0 
            ? Color(red: 0.2, green: 0.7, blue: 0.4) 
            : Color(red: 0.9, green: 0.3, blue: 0.3)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(result.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: result.deltaFromBase >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                    Text(abs(result.deltaFromBase).asCurrency)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }
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

// MARK: - Deal Optimizer Sheet

struct DealOptimizerSheet: View {
    @Bindable var viewModel: PropertyDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Local state for sliders (to avoid modifying actual property until applied)
    @State private var purchasePrice: Double
    @State private var monthlyRent: Double
    @State private var interestRate: Double
    @State private var ltv: Double
    @State private var showingOptimalPrice: Bool = false
    @State private var optimalPriceResult: OptimalPriceResult?
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    // Price range: 70% to 130% of asking price
    private var priceRange: ClosedRange<Double> {
        let asking = viewModel.property.askingPrice
        let minPrice = max(asking * 0.70, 50000)
        let maxPrice = asking * 1.30
        return minPrice...maxPrice
    }
    
    // Rent range: 50% to 150% of estimated rent
    private var rentRange: ClosedRange<Double> {
        let baseRent = viewModel.property.estimatedRentPerUnit > 0 
            ? viewModel.property.estimatedRentPerUnit 
            : viewModel.property.askingPrice * 0.008 // Rough estimate
        return max(baseRent * 0.50, 500)...baseRent * 1.50
    }
    
    init(viewModel: PropertyDetailViewModel) {
        self.viewModel = viewModel
        let property = viewModel.property
        let financing = property.financing
        
        _purchasePrice = State(initialValue: financing.purchasePrice > 0 ? financing.purchasePrice : property.askingPrice)
        _monthlyRent = State(initialValue: property.estimatedRentPerUnit > 0 ? property.estimatedRentPerUnit : property.askingPrice * 0.008)
        _interestRate = State(initialValue: financing.interestRate)
        _ltv = State(initialValue: financing.ltv)
    }
    
    // Calculate metrics based on current slider values
    private var simulatedMetrics: SimulatedDealMetrics {
        var testProperty = viewModel.property
        testProperty.financing.purchasePrice = purchasePrice
        testProperty.financing.ltv = ltv
        testProperty.financing.loanAmount = purchasePrice * ltv
        testProperty.financing.interestRate = interestRate
        testProperty.estimatedRentPerUnit = monthlyRent
        testProperty.estimatedTotalRent = monthlyRent * Double(testProperty.unitCount)
        
        let economics = UnderwritingEngine.calculateDealEconomics(for: testProperty)
        let thresholds = viewModel.property.thresholds
        
        return SimulatedDealMetrics(
            capRate: economics.inPlaceCapRate,
            cashOnCash: economics.cashOnCashReturn,
            dscr: economics.dscr,
            monthlyCashFlow: economics.monthlyCashFlow,
            annualCashFlow: economics.annualCashFlow,
            totalCashRequired: (purchasePrice * (1 - ltv)) + viewModel.property.financing.closingCosts,
            noi: economics.netOperatingIncome,
            capRateMeetsTarget: economics.inPlaceCapRate >= thresholds.targetCapRate,
            cashOnCashMeetsTarget: economics.cashOnCashReturn >= thresholds.targetCashOnCash,
            dscrMeetsTarget: economics.dscr >= thresholds.targetDSCR,
            cashFlowPositive: economics.monthlyCashFlow > 0
        )
    }
    
    // Calculate comparison to asking price
    private var priceVsAskingPercent: Double {
        guard viewModel.property.askingPrice > 0 else { return 0 }
        return (purchasePrice - viewModel.property.askingPrice) / viewModel.property.askingPrice
    }
    
    private var allMetricsMet: Bool {
        let metrics = simulatedMetrics
        return metrics.capRateMeetsTarget && 
               metrics.cashOnCashMeetsTarget && 
               metrics.dscrMeetsTarget && 
               metrics.cashFlowPositive
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with current vs asking comparison
                    priceComparisonHeader
                    
                    // Key metrics display
                    metricsOverview
                    
                    // Sliders section
                    slidersSection
                    
                    // Optimal price finder
                    optimalPriceFinder
                    
                    // Apply changes button
                    applyButton
                }
                .padding(.vertical, 24)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Deal Optimizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        resetToOriginal()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Price Comparison Header
    
    private var priceComparisonHeader: some View {
        VStack(spacing: 16) {
            // Current price display
            VStack(spacing: 4) {
                Text("Purchase Price")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(purchasePrice.asCompactCurrency)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                // Comparison to asking
                HStack(spacing: 6) {
                    let diff = purchasePrice - viewModel.property.askingPrice
                    Image(systemName: diff >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption)
                    Text("\(abs(diff).asCompactCurrency) (\(abs(priceVsAskingPercent * 100).formatted(decimals: 1))%)")
                        .font(.caption)
                    Text("vs asking")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(priceVsAskingPercent >= 0 ? Color(red: 0.9, green: 0.3, blue: 0.3) : Color(red: 0.2, green: 0.7, blue: 0.4))
            }
            
            // Deal quality indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(allMetricsMet ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color(red: 1.0, green: 0.6, blue: 0.2))
                    .frame(width: 10, height: 10)
                
                Text(allMetricsMet ? "All targets met" : "Some targets not met")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(allMetricsMet ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color(red: 1.0, green: 0.6, blue: 0.2))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                (allMetricsMet ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color(red: 1.0, green: 0.6, blue: 0.2))
                    .opacity(0.12)
            )
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Metrics Overview
    
    private var metricsOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            // Primary metrics grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                OptimizerMetricCard(
                    title: "Cap Rate",
                    value: simulatedMetrics.capRate.asPercent(),
                    target: viewModel.property.thresholds.targetCapRate.asPercent(),
                    meetsTarget: simulatedMetrics.capRateMeetsTarget,
                    background: cardBackground
                )
                
                OptimizerMetricCard(
                    title: "Cash-on-Cash",
                    value: simulatedMetrics.cashOnCash.asPercent(),
                    target: viewModel.property.thresholds.targetCashOnCash.asPercent(),
                    meetsTarget: simulatedMetrics.cashOnCashMeetsTarget,
                    background: cardBackground
                )
                
                OptimizerMetricCard(
                    title: "DSCR",
                    value: String(format: "%.2fx", simulatedMetrics.dscr),
                    target: String(format: "%.2fx", viewModel.property.thresholds.targetDSCR),
                    meetsTarget: simulatedMetrics.dscrMeetsTarget,
                    background: cardBackground
                )
                
                OptimizerMetricCard(
                    title: "Monthly Cash Flow",
                    value: simulatedMetrics.monthlyCashFlow.asCurrency,
                    target: "> $0",
                    meetsTarget: simulatedMetrics.cashFlowPositive,
                    background: cardBackground
                )
            }
            .padding(.horizontal, 20)
            
            // Secondary metrics
            HStack(spacing: 12) {
                SecondaryMetricPill(
                    title: "Cash Required",
                    value: simulatedMetrics.totalCashRequired.asCompactCurrency,
                    background: cardBackground
                )
                
                SecondaryMetricPill(
                    title: "Annual NOI",
                    value: simulatedMetrics.noi.asCompactCurrency,
                    background: cardBackground
                )
                
                SecondaryMetricPill(
                    title: "Annual Cash Flow",
                    value: simulatedMetrics.annualCashFlow.asCompactCurrency,
                    background: cardBackground
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Sliders Section
    
    private var slidersSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Adjust Variables")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                // Purchase Price Slider
                OptimizerSlider(
                    title: "Purchase Price",
                    value: $purchasePrice,
                    range: priceRange,
                    step: 5000,
                    format: .currency,
                    accentColor: .blue
                )
                
                // Monthly Rent Slider
                OptimizerSlider(
                    title: "Monthly Rent",
                    value: $monthlyRent,
                    range: rentRange,
                    step: 50,
                    format: .currency,
                    accentColor: .green
                )
                
                // Interest Rate Slider
                OptimizerSlider(
                    title: "Interest Rate",
                    value: $interestRate,
                    range: 0.04...0.12,
                    step: 0.0025,
                    format: .percent,
                    accentColor: .orange
                )
                
                // LTV (Down Payment) Slider
                OptimizerSlider(
                    title: "Loan-to-Value (LTV)",
                    value: $ltv,
                    range: 0.50...0.95,
                    step: 0.05,
                    format: .percent,
                    subtitle: "Down Payment: \((purchasePrice * (1 - ltv)).asCompactCurrency)",
                    accentColor: .purple
                )
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Optimal Price Finder
    
    private var optimalPriceFinder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find Optimal Price")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                Text("Calculate the maximum purchase price that meets all your target thresholds with current assumptions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button {
                    calculateOptimalPrice()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.subheadline)
                        Text("Find Optimal Price")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                
                if let result = optimalPriceResult {
                    VStack(spacing: 12) {
                        Divider()
                        
                        if result.foundOptimal {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Optimal Price")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(result.optimalPrice.asCompactCurrency)
                                        .font(.system(.title3, design: .rounded, weight: .bold))
                                        .foregroundStyle(.primary)
                                }
                                
                                HStack {
                                    Text("Savings vs Asking")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text((viewModel.property.askingPrice - result.optimalPrice).asCompactCurrency)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.4))
                                }
                                
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        purchasePrice = result.optimalPrice
                                    }
                                    HapticManager.shared.success()
                                } label: {
                                    Text("Apply Optimal Price")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(red: 0.2, green: 0.7, blue: 0.4))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Apply Button
    
    private var applyButton: some View {
        Button {
            applyChanges()
        } label: {
            Text("Apply to Property")
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
    
    // MARK: - Actions
    
    private func resetToOriginal() {
        withAnimation(.spring(response: 0.3)) {
            let property = viewModel.property
            purchasePrice = property.financing.purchasePrice > 0 ? property.financing.purchasePrice : property.askingPrice
            monthlyRent = property.estimatedRentPerUnit > 0 ? property.estimatedRentPerUnit : property.askingPrice * 0.008
            interestRate = property.financing.interestRate
            ltv = property.financing.ltv
            optimalPriceResult = nil
        }
        HapticManager.shared.impact(.light)
    }
    
    private func calculateOptimalPrice() {
        let thresholds = viewModel.property.thresholds
        var testPrice = viewModel.property.askingPrice
        let minPrice = priceRange.lowerBound
        let step: Double = 5000
        
        var foundPrice: Double? = nil
        
        // Binary search would be more efficient, but let's do iterative for clarity
        while testPrice >= minPrice {
            var testProperty = viewModel.property
            testProperty.financing.purchasePrice = testPrice
            testProperty.financing.ltv = ltv
            testProperty.financing.loanAmount = testPrice * ltv
            testProperty.financing.interestRate = interestRate
            testProperty.estimatedRentPerUnit = monthlyRent
            testProperty.estimatedTotalRent = monthlyRent * Double(testProperty.unitCount)
            
            let economics = UnderwritingEngine.calculateDealEconomics(for: testProperty)
            
            let meetsCapRate = economics.inPlaceCapRate >= thresholds.targetCapRate
            let meetsCashOnCash = economics.cashOnCashReturn >= thresholds.targetCashOnCash
            let meetsDSCR = economics.dscr >= thresholds.targetDSCR
            let positiveCashFlow = economics.monthlyCashFlow > 0
            
            if meetsCapRate && meetsCashOnCash && meetsDSCR && positiveCashFlow {
                foundPrice = testPrice
                break
            }
            
            testPrice -= step
        }
        
        if let optimal = foundPrice {
            // Now find the maximum price that still meets all criteria
            var maxOptimal = optimal
            var searchPrice = optimal + step
            
            while searchPrice <= viewModel.property.askingPrice {
                var testProperty = viewModel.property
                testProperty.financing.purchasePrice = searchPrice
                testProperty.financing.ltv = ltv
                testProperty.financing.loanAmount = searchPrice * ltv
                testProperty.financing.interestRate = interestRate
                testProperty.estimatedRentPerUnit = monthlyRent
                testProperty.estimatedTotalRent = monthlyRent * Double(testProperty.unitCount)
                
                let economics = UnderwritingEngine.calculateDealEconomics(for: testProperty)
                
                let meetsAll = economics.inPlaceCapRate >= thresholds.targetCapRate &&
                              economics.cashOnCashReturn >= thresholds.targetCashOnCash &&
                              economics.dscr >= thresholds.targetDSCR &&
                              economics.monthlyCashFlow > 0
                
                if meetsAll {
                    maxOptimal = searchPrice
                }
                
                searchPrice += step
            }
            
            optimalPriceResult = OptimalPriceResult(
                foundOptimal: true,
                optimalPrice: maxOptimal,
                message: "Found optimal purchase price"
            )
        } else {
            optimalPriceResult = OptimalPriceResult(
                foundOptimal: false,
                optimalPrice: 0,
                message: "No price in range meets all targets.\nTry adjusting rent, rate, or LTV."
            )
        }
        
        HapticManager.shared.notification(foundPrice != nil ? .success : .warning)
    }
    
    private func applyChanges() {
        viewModel.property.financing.purchasePrice = purchasePrice
        viewModel.property.financing.ltv = ltv
        viewModel.property.financing.loanAmount = purchasePrice * ltv
        viewModel.property.financing.interestRate = interestRate
        viewModel.property.estimatedRentPerUnit = monthlyRent
        viewModel.property.estimatedTotalRent = monthlyRent * Double(viewModel.property.unitCount)
        
        HapticManager.shared.success()
        dismiss()
    }
}

// MARK: - Deal Optimizer Supporting Types

struct SimulatedDealMetrics {
    let capRate: Double
    let cashOnCash: Double
    let dscr: Double
    let monthlyCashFlow: Double
    let annualCashFlow: Double
    let totalCashRequired: Double
    let noi: Double
    let capRateMeetsTarget: Bool
    let cashOnCashMeetsTarget: Bool
    let dscrMeetsTarget: Bool
    let cashFlowPositive: Bool
}

struct OptimalPriceResult {
    let foundOptimal: Bool
    let optimalPrice: Double
    let message: String
}

// MARK: - Deal Optimizer Components

struct OptimizerMetricCard: View {
    let title: String
    let value: String
    let target: String
    let meetsTarget: Bool
    let background: Color
    
    private var statusColor: Color {
        meetsTarget ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color(red: 0.9, green: 0.3, blue: 0.3)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Target: \(target)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SecondaryMetricPill: View {
    let title: String
    let value: String
    let background: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct OptimizerSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: SliderFormat
    var subtitle: String? = nil
    let accentColor: Color
    
    enum SliderFormat {
        case currency
        case percent
    }
    
    private var displayValue: String {
        switch format {
        case .currency:
            return value.asCompactCurrency
        case .percent:
            return (value * 100).formatted(decimals: 2) + "%"
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                Text(displayValue)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            
            Slider(value: $value, in: range, step: step) { editing in
                if editing {
                    HapticManager.shared.slider()
                }
            }
            .tint(accentColor)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PropertyDetailView(property: .preview, onSave: { _ in })
    }
}
