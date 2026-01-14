//
//  AddPropertyView.swift
//  Dock
//
//  Add new property flow
//

import SwiftUI

struct AddPropertyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = AddPropertyViewModel()
    
    let onAdd: (Property) -> Void
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressIndicator
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    
                    // Content
                    TabView(selection: Binding(
                        get: { viewModel.step.rawValue },
                        set: { viewModel.step = AddPropertyViewModel.AddPropertyStep(rawValue: $0) ?? .address }
                    )) {
                        addressStep
                            .tag(0)
                        
                        detailsStep
                            .tag(1)
                        
                        financingStep
                            .tag(2)
                        
                        reviewStep
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: viewModel.step)
                    
                    // Bottom buttons
                    bottomButtons
                        .padding(20)
                }
            }
            .navigationTitle("Add Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { index in
                Capsule()
                    .fill(index <= viewModel.step.rawValue ? Color.primary : Color.primary.opacity(0.15))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Address Step
    
    private var addressStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter Property Address")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Start typing an address and select from suggestions to auto-fill property details.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                
                AddressSearchField(
                    title: "Property Address",
                    selectedAddress: $viewModel.searchAddress,
                    autoFocus: true
                ) { suggestion in
                    viewModel.handleAddressSelection(suggestion)
                }
                
                if viewModel.isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Fetching property data...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                
                Button {
                    viewModel.skipAddress()
                } label: {
                    Text("Enter manually instead")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Details Step
    
    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Address Section
                ModernFormSection(title: "Address", icon: "mappin.circle.fill", cardBackground: cardBackground) {
                    TextInputField(title: "Street Address", text: $viewModel.property.address, icon: "house")
                    
                    HStack(spacing: 12) {
                        TextInputField(title: "City", text: $viewModel.property.city)
                        
                        TextInputField(title: "State", text: $viewModel.property.state)
                            .frame(width: 80)
                        
                        TextInputField(title: "ZIP", text: $viewModel.property.zipCode)
                            .frame(width: 80)
                    }
                }
                
                // Property Details
                ModernFormSection(title: "Property Details", icon: "building.2.fill", cardBackground: cardBackground) {
                    CurrencyField(title: "Asking Price", value: $viewModel.property.askingPrice)
                    
                    HStack(spacing: 12) {
                        ModernStepperField(title: "Beds", value: $viewModel.property.bedrooms, cardBackground: cardBackground)
                        
                        ModernBathroomField(title: "Baths", value: $viewModel.property.bathrooms, cardBackground: cardBackground)
                    }
                    
                    HStack(spacing: 12) {
                        NumberField(title: "Square Feet", value: $viewModel.property.squareFeet, suffix: "sq ft")
                        NumberField(title: "Lot Size", value: $viewModel.property.lotSize, suffix: "sq ft")
                    }
                    
                    HStack(spacing: 12) {
                        NumberField(title: "Year Built", value: $viewModel.property.yearBuilt)
                        ModernStepperField(title: "Units", value: $viewModel.property.unitCount, range: 1...100, cardBackground: cardBackground)
                    }
                    
                    // Property Type
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Property Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(PropertyType.allCases, id: \.self) { type in
                                    ModernPropertyTypeChip(
                                        type: type,
                                        isSelected: viewModel.property.propertyType == type,
                                        colorScheme: colorScheme
                                    ) {
                                        viewModel.property.propertyType = type
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Taxes & Insurance
                ModernFormSection(title: "Taxes & Insurance", icon: "doc.text.fill", cardBackground: cardBackground) {
                    HStack(spacing: 12) {
                        CurrencyField(title: "Tax Assessed Value", value: $viewModel.property.taxAssessedValue)
                        CurrencyField(title: "Annual Taxes", value: $viewModel.property.annualTaxes)
                    }
                    
                    CurrencyField(title: "Annual Insurance", value: $viewModel.property.insuranceAnnual)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Financing Step
    
    private var financingStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Purchase Price
                ModernFormSection(title: "Purchase", icon: "dollarsign.circle.fill", cardBackground: cardBackground) {
                    CurrencyField(title: "Purchase Price", value: $viewModel.property.financing.purchasePrice)
                    CurrencyField(title: "Closing Costs", value: $viewModel.property.financing.closingCosts)
                }
                
                // Loan Details
                ModernFormSection(title: "Financing", icon: "banknote.fill", cardBackground: cardBackground) {
                    SliderField(
                        title: "Loan-to-Value (LTV)",
                        value: $viewModel.property.financing.ltv,
                        range: 0...0.95,
                        step: 0.05,
                        format: .percent
                    )
                    .onChange(of: viewModel.property.financing.ltv) { _, _ in
                        viewModel.property.financing.updateLoanFromLTV()
                    }
                    
                    CurrencyField(title: "Loan Amount", value: $viewModel.property.financing.loanAmount)
                        .onChange(of: viewModel.property.financing.loanAmount) { _, _ in
                            viewModel.property.financing.updateLTVFromLoan()
                        }
                    
                    PercentField(title: "Interest Rate", value: $viewModel.property.financing.interestRate)
                    
                    SliderField(
                        title: "Loan Term",
                        value: Binding(
                            get: { Double(viewModel.property.financing.loanTermYears) },
                            set: { viewModel.property.financing.loanTermYears = Int($0) }
                        ),
                        range: 5...30,
                        step: 5,
                        format: .years
                    )
                }
                
                // Income
                ModernFormSection(title: "Income", icon: "chart.line.uptrend.xyaxis", cardBackground: cardBackground) {
                    CurrencyField(title: "Estimated Rent (per unit/mo)", value: $viewModel.property.estimatedRentPerUnit)
                        .onChange(of: viewModel.property.estimatedRentPerUnit) { _, newValue in
                            viewModel.property.estimatedTotalRent = newValue * Double(viewModel.property.unitCount)
                        }
                    
                    if viewModel.property.unitCount > 1 {
                        ModernDisplayRow(title: "Total Monthly Rent", value: viewModel.property.estimatedTotalRent.asCurrency, cardBackground: cardBackground)
                    }
                    
                    SliderField(
                        title: "Vacancy Rate",
                        value: $viewModel.property.vacancyRate,
                        range: 0...0.20,
                        step: 0.01,
                        format: .percent
                    )
                }
                
                // Expenses
                ModernFormSection(title: "Operating Expenses", icon: "arrow.down.circle.fill", cardBackground: cardBackground) {
                    SliderField(
                        title: "Management Fee",
                        value: $viewModel.property.managementFeePercent,
                        range: 0...0.15,
                        step: 0.01,
                        format: .percent
                    )
                    
                    CurrencyField(title: "Repairs/Maintenance (per unit/year)", value: $viewModel.property.repairsPerUnit)
                    CurrencyField(title: "Other Expenses (annual)", value: $viewModel.property.otherExpenses)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Review Step
    
    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                let metrics = viewModel.property.metrics
                
                // Property Header Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.property.askingPrice.asCompactCurrency)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            
                            Text(viewModel.property.address)
                                .font(.subheadline)
                            
                            Text("\(viewModel.property.city), \(viewModel.property.state) \(viewModel.property.zipCode)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Score
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 4)
                                .frame(width: 56, height: 56)
                            
                            Circle()
                                .trim(from: 0, to: metrics.overallScore / 100)
                                .stroke(metrics.recommendation.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 56, height: 56)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(Int(metrics.overallScore))")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                    }
                    
                    Divider()
                    
                    HStack(spacing: 20) {
                        ReviewStat(value: "\(viewModel.property.bedrooms)", label: "Beds")
                        ReviewStat(value: String(format: "%.1f", viewModel.property.bathrooms), label: "Baths")
                        ReviewStat(value: viewModel.property.squareFeet.withCommas, label: "Sq Ft")
                        if viewModel.property.unitCount > 1 {
                            ReviewStat(value: "\(viewModel.property.unitCount)", label: "Units")
                        }
                    }
                }
                .padding(20)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Recommendation Card
                HStack(spacing: 16) {
                    Circle()
                        .fill(metrics.recommendation.color)
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: metrics.recommendation.icon)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metrics.recommendation.rawValue)
                            .font(.headline)
                        
                        Text(metrics.recommendation.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Key Metrics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Key Metrics")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ModernReviewMetricCard(
                            title: "Cap Rate",
                            value: metrics.dealEconomics.inPlaceCapRate.asPercent(),
                            score: UnderwritingEngine.scoreCapRate(
                                metrics.dealEconomics.inPlaceCapRate,
                                target: viewModel.property.thresholds.targetCapRate
                            ),
                            cardBackground: cardBackground
                        )
                        
                        ModernReviewMetricCard(
                            title: "Cash-on-Cash",
                            value: metrics.dealEconomics.cashOnCashReturn.asPercent(),
                            score: UnderwritingEngine.scoreCashOnCash(
                                metrics.dealEconomics.cashOnCashReturn,
                                target: viewModel.property.thresholds.targetCashOnCash
                            ),
                            cardBackground: cardBackground
                        )
                        
                        ModernReviewMetricCard(
                            title: "DSCR",
                            value: String(format: "%.2fx", metrics.dealEconomics.dscr),
                            score: UnderwritingEngine.scoreDSCR(
                                metrics.dealEconomics.dscr,
                                target: viewModel.property.thresholds.targetDSCR
                            ),
                            cardBackground: cardBackground
                        )
                        
                        ModernReviewMetricCard(
                            title: "Monthly Cash Flow",
                            value: metrics.dealEconomics.monthlyCashFlow.asCurrency,
                            score: metrics.dealEconomics.monthlyCashFlow > 0 ? .meets : .fails,
                            cardBackground: cardBackground
                        )
                    }
                }
                
                // Financial Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Financial Summary")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 0) {
                        ModernFinancialRow(title: "Purchase Price", value: viewModel.property.financing.purchasePrice.asCurrency)
                        Divider().padding(.leading, 16)
                        ModernFinancialRow(title: "Down Payment", value: viewModel.property.financing.downPayment.asCurrency)
                        Divider().padding(.leading, 16)
                        ModernFinancialRow(title: "Loan Amount", value: viewModel.property.financing.loanAmount.asCurrency)
                        Divider().padding(.leading, 16)
                        ModernFinancialRow(title: "Total Cash Required", value: viewModel.property.financing.totalCashRequired.asCurrency, isHighlighted: true)
                    }
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                // Income & Expenses
                VStack(alignment: .leading, spacing: 12) {
                    Text("Income & Expenses")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 0) {
                        ModernFinancialRow(title: "Gross Potential Rent", value: metrics.dealEconomics.grossPotentialRent.asCurrency, valueColor: .green)
                        Divider().padding(.leading, 16)
                        ModernFinancialRow(title: "Operating Expenses", value: "-\(metrics.dealEconomics.totalOperatingExpenses.asCurrency)", valueColor: .red)
                        Divider().padding(.leading, 16)
                        ModernFinancialRow(title: "Net Operating Income", value: metrics.dealEconomics.netOperatingIncome.asCurrency, isHighlighted: true)
                        Divider().padding(.leading, 16)
                        ModernFinancialRow(title: "Annual Debt Service", value: "-\(metrics.dealEconomics.annualDebtService.asCurrency)", valueColor: .red)
                        Divider().padding(.leading, 16)
                        ModernFinancialRow(title: "Annual Cash Flow", value: metrics.dealEconomics.annualCashFlow.asCurrency, isHighlighted: true, valueColor: metrics.dealEconomics.annualCashFlow >= 0 ? .green : .red)
                    }
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if viewModel.step.rawValue > 0 {
                Button {
                    viewModel.previousStep()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline)
                        Text("Back")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(cardBackground)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            
            Button {
                if viewModel.step == .address && !viewModel.hasAttemptedFetch && viewModel.hasValidAddress {
                    Task {
                        await viewModel.fetchFromAddress()
                    }
                } else if viewModel.step == .review {
                    onAdd(viewModel.property)
                    dismiss()
                } else {
                    viewModel.nextStep()
                }
            } label: {
                HStack(spacing: 6) {
                    Group {
                        if viewModel.step == .address && !viewModel.hasAttemptedFetch {
                            Text("Fetch Property")
                            Image(systemName: "arrow.down.circle")
                        } else if viewModel.step == .review {
                            Text("Add Property")
                            Image(systemName: "checkmark.circle")
                        } else {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .font(.subheadline)
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primary)
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!viewModel.canProceed && viewModel.step != .address)
        }
    }
}

// MARK: - Modern Form Components

struct ModernFormSection<Content: View>: View {
    let title: String
    let icon: String
    let cardBackground: Color
    let content: Content
    
    init(title: String, icon: String, cardBackground: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.cardBackground = cardBackground
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 14) {
                content
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ModernStepperField: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...99
    let cardBackground: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Button {
                    if value > range.lowerBound {
                        value -= 1
                        Task { @MainActor in
                            HapticManager.shared.impact(.light)
                        }
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(value > range.lowerBound ? .primary : .tertiary)
                }
                
                Spacer()
                
                Text("\(value)")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                
                Spacer()
                
                Button {
                    if value < range.upperBound {
                        value += 1
                        Task { @MainActor in
                            HapticManager.shared.impact(.light)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(value < range.upperBound ? .primary : .tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct ModernBathroomField: View {
    let title: String
    @Binding var value: Double
    let cardBackground: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Button {
                    if value > 0 {
                        value -= 0.5
                        Task { @MainActor in
                            HapticManager.shared.impact(.light)
                        }
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(value > 0 ? .primary : .tertiary)
                }
                
                Spacer()
                
                Text(String(format: "%.1f", value))
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                
                Spacer()
                
                Button {
                    value += 0.5
                    Task { @MainActor in
                        HapticManager.shared.impact(.light)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct ModernDisplayRow: View {
    let title: String
    let value: String
    let cardBackground: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ModernPropertyTypeChip: View {
    let type: PropertyType
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.caption)
                
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary : Color.clear)
            .foregroundStyle(isSelected ? (colorScheme == .dark ? Color.black : Color.white) : .primary)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule()
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ReviewStat: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ModernReviewMetricCard: View {
    let title: String
    let value: String
    let score: MetricScore
    let cardBackground: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Circle()
                    .fill(score.color.opacity(0.15))
                    .frame(width: 20, height: 20)
                    .overlay {
                        Image(systemName: score.icon)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(score.color)
                    }
            }
            
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(score.color)
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ModernFinancialRow: View {
    let title: String
    let value: String
    var isHighlighted: Bool = false
    var valueColor: Color? = nil
    
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

// MARK: - Legacy Support

struct FormSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 14) {
                content
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CompactStepperField: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...99
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Button {
                    if value > range.lowerBound {
                        value -= 1
                        Task { @MainActor in
                            HapticManager.shared.impact(.light)
                        }
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value > range.lowerBound ? .accentColor : Color(.tertiaryLabel))
                }
                
                Spacer()
                
                Text("\(value)")
                    .font(.system(.title2, design: .rounded, weight: .medium))
                
                Spacer()
                
                Button {
                    if value < range.upperBound {
                        value += 1
                        Task { @MainActor in
                            HapticManager.shared.impact(.light)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value < range.upperBound ? .accentColor : Color(.tertiaryLabel))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 0.5)
            }
        }
    }
}

struct CompactBathroomField: View {
    let title: String
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Button {
                    if value > 0 {
                        value -= 0.5
                        Task { @MainActor in
                            HapticManager.shared.impact(.light)
                        }
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value > 0 ? .accentColor : Color(.tertiaryLabel))
                }
                
                Spacer()
                
                Text(String(format: "%.1f", value))
                    .font(.system(.title2, design: .rounded, weight: .medium))
                
                Spacer()
                
                Button {
                    value += 0.5
                    Task { @MainActor in
                        HapticManager.shared.impact(.light)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 0.5)
            }
        }
    }
}

struct InlineDisplayRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
    }
}

struct PropertyStat: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

struct ReviewMetricCard: View {
    let title: String
    let value: String
    let score: MetricScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: score.icon)
                    .font(.caption)
                    .foregroundStyle(score.color)
            }
            
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(score.color)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct FinancialRow: View {
    let title: String
    let value: String
    var isHighlighted: Bool = false
    var valueColor: Color? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(isHighlighted ? .subheadline.weight(.medium) : .subheadline)
                .foregroundStyle(isHighlighted ? .primary : .secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(isHighlighted ? .subheadline : .subheadline, design: .rounded, weight: isHighlighted ? .semibold : .regular))
                .foregroundStyle(valueColor ?? (isHighlighted ? .primary : .secondary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct PropertyTypeChip: View {
    let type: PropertyType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.caption)
                
                Text(type.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isHighlighted ? .primary : .secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: isHighlighted ? .semibold : .regular))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    AddPropertyView { _ in }
}
