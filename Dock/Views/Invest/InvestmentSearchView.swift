//
//  InvestmentSearchView.swift
//  Dock
//
//  Find investment opportunities by location and targets
//

import SwiftUI

struct InvestmentSearchView: View {
    @Bindable var homeViewModel: HomeViewModel
    @State private var viewModel = InvestmentSearchViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @FocusState private var dscrFocused: Bool
    @State private var isFormCollapsed = false

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }

    private var capRateBinding: Binding<Double> {
        Binding(
            get: { viewModel.criteria.targetCapRate },
            set: { newValue in
                viewModel.criteria.targetCapRate = newValue
                viewModel.criteria.minCapRate = newValue
            }
        )
    }

    private var cashOnCashBinding: Binding<Double> {
        Binding(
            get: { viewModel.criteria.targetCashOnCash },
            set: { newValue in
                viewModel.criteria.targetCashOnCash = newValue
                viewModel.criteria.minCashOnCash = newValue
            }
        )
    }

    private var dscrBinding: Binding<Double> {
        Binding(
            get: { viewModel.criteria.targetDSCR },
            set: { newValue in
                viewModel.criteria.targetDSCR = newValue
                viewModel.criteria.minDSCR = newValue
            }
        )
    }

    init(homeViewModel: HomeViewModel) {
        self.homeViewModel = homeViewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        if !homeViewModel.marketRateItems.isEmpty {
                            ratesAutoScrollView
                                .frame(height: 50)
                        }

                        searchSection

                        if viewModel.isLoading {
                            loadingSection
                        }

                        if !viewModel.results.isEmpty {
                            resultsSection
                        }

                        if !viewModel.history.isEmpty {
                            historySection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Smart Investor")
                        .font(.title2)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: true, vertical: true)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .alert("Search Error", isPresented: Binding(get: {
                viewModel.errorMessage != nil
            }, set: { _ in
                viewModel.errorMessage = nil
            })) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var searchSection: some View {
        Group {
            if isFormCollapsed {
                collapsedFormSummary
            } else {
                formSection
            }
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search Filters")
                    .font(.headline)

                Spacer()

                Button("Reset") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.resetCriteria()
                    }
                    HapticManager.shared.selection()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            TextInputField(
                title: "City, State, or ZIP",
                text: $viewModel.criteria.location,
                placeholder: "Austin, TX or 78701",
                icon: "mappin.and.ellipse"
            )

            HStack(spacing: 12) {
                CurrencyField(title: "Min Budget", value: $viewModel.criteria.minPrice)
                CurrencyField(title: "Max Budget", value: $viewModel.criteria.maxPrice)
            }

            HStack(spacing: 12) {
                NumberField(title: "Min Beds", value: $viewModel.criteria.minBeds)
                NumberField(title: "Min Baths", value: $viewModel.criteria.minBaths)
            }

            HStack(spacing: 12) {
                NumberField(title: "Min Sqft", value: $viewModel.criteria.minSqft)
                NumberField(title: "Min Lot", value: $viewModel.criteria.minLotSqft)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Target Returns")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    PercentField(title: "Cap Rate", value: capRateBinding)
                    PercentField(title: "Cash-on-Cash", value: cashOnCashBinding)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("DSCR")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("1.25", value: dscrBinding, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($dscrFocused)
                        .inputFieldStyle(isFocused: dscrFocused)
                }
            }

            Button {
                Task {
                    await viewModel.search()
                    if viewModel.errorMessage == nil {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFormCollapsed = true
                        }
                    }
                }
            } label: {
                Text("Find Investments")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary)
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .clipShape(Capsule())
            }
        }
    }

    private var loadingSection: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Scoring the best listings...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Matches")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.results.count) results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVStack(spacing: 16) {
                ForEach(viewModel.results) { result in
                    investmentResultPropertyCard(for: result)
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previous Searches")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(viewModel.history) { item in
                    Button {
                        viewModel.applyHistory(item)
                        Task {
                            await viewModel.search()
                            if viewModel.errorMessage == nil {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isFormCollapsed = true
                                }
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.criteria.location)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Text("Avg score \(Int(item.averageScore)) • \(item.resultCount) listings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(item.searchedAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func isTracked(_ result: InvestmentSearchResult) -> Bool {
        homeViewModel.properties.contains { property in
            if let listingURL = result.property.listingURL, !listingURL.isEmpty {
                return property.listingURL == listingURL
            }
            return property.address == result.property.address && property.zipCode == result.property.zipCode
        }
    }

    // MARK: - Rates Auto Scroll View

    @ViewBuilder
    private var ratesAutoScrollView: some View {
        if homeViewModel.marketRateItems.count > 0 {
            LoopingScrollView(
                spacing: 15,
                scrollingSpeed: 0.5,
                itemWidth: 160,
                data: homeViewModel.marketRateItems
            ) { item, isRepeated in
                RateItemView(item: item, showChart: true)
            }
        }
    }

    private var collapsedFormSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Search Filters")
                    .font(.headline)

                Spacer()

                Button("Edit") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFormCollapsed = false
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Text(filterSummaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var filterSummaryText: String {
        let locationText = viewModel.criteria.location.isEmpty ? "Any location" : viewModel.criteria.location
        let minPrice = viewModel.criteria.minPrice > 0 ? viewModel.criteria.minPrice.asCompactCurrency : "No min"
        let maxPrice = viewModel.criteria.maxPrice > 0 ? viewModel.criteria.maxPrice.asCompactCurrency : "No max"
        return "\(locationText) • \(minPrice) - \(maxPrice)"
    }

    private func investmentResultPropertyCard(for result: InvestmentSearchResult) -> some View {
        let property = viewModel.propertyForTracking(from: result)
        return Button {
            if let urlString = result.property.listingURL,
               let url = URL(string: urlString) {
                openURL(url)
            }
        } label: {
            PropertyCard(
                property: property,
                cardBackground: cardBackground,
                colorScheme: colorScheme,
                onPin: {},
                onDelete: {},
                showsContextMenu: false,
                topTrailingAccessory: AnyView(
                    Button {
                        Task {
                            let trackedProperty = viewModel.propertyForTracking(from: result)
                            await homeViewModel.addProperty(trackedProperty)
                        }
                    } label: {
                        Image(systemName: isTracked(result) ? "checkmark" : "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isTracked(result) ? .green : .primary)
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .disabled(isTracked(result))
                )
            )
        }
        .buttonStyle(.plain)
    }
}
