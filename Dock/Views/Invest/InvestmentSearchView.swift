//
//  InvestmentSearchView.swift
//  Dock
//
//  Find investment opportunities by location and targets
//

import SwiftUI
import MapKit

struct InvestmentSearchView: View {
    @Bindable var homeViewModel: HomeViewModel
    @State private var viewModel = InvestmentSearchViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    
    // Location search
    @State private var locationQuery: String = ""
    
    // Form state
    @State private var isFiltersExpanded = false
    @FocusState private var dscrFocused: Bool
    
    // Animation state
    @State private var resultsAppeared = false

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    private var hasValidLocation: Bool {
        !viewModel.criteria.location.trimmed.isEmpty
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

                Group {
                    switch viewModel.searchPhase {
                    case .idle:
                        idleContent
                    case .analyzing:
                        analyzingContent
                    case .complete:
                        resultsContent
                    }
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
                
                if viewModel.searchPhase == .complete {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.resetSearch()
                                resultsAppeared = false
                            }
                        } label: {
                            Text("New Search")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
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
    
    // MARK: - Idle State (Search Form)
    
    private var idleContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if !homeViewModel.marketRateItems.isEmpty {
                    ratesAutoScrollView
                        .frame(height: 50)
                }

                searchFormSection
                
                if !viewModel.history.isEmpty {
                    historySection
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Search Form Section
    
    private var searchFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Location field using AddressSearchField pattern
            LocationSearchField(
                title: "Location",
                selectedLocation: $viewModel.criteria.location
            )
            
            // Edit/Hide filters toggle
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isFiltersExpanded.toggle()
                }
                HapticManager.shared.selection()
            } label: {
                HStack(spacing: 4) {
                    Text(isFiltersExpanded ? "Hide filters" : "Edit filters")
                        .font(.subheadline)
                    
                    if !isFiltersExpanded {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(viewModel.criteria.filterSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            // Expanded filters
            if isFiltersExpanded {
                expandedFiltersContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Search button
            Button {
                dscrFocused = false
                Task {
                    await viewModel.search()
                    if viewModel.errorMessage == nil {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            resultsAppeared = true
                        }
                    }
                }
            } label: {
                Text("Find Investments")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hasValidLocation ? Color.primary : Color.clear)
                    .foregroundStyle(hasValidLocation ? (colorScheme == .dark ? .black : .white) : .primary)
                    .clipShape(Capsule())
                    .overlay {
                        if !hasValidLocation {
                            Capsule()
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1.5)
                        }
                    }
            }
            .disabled(!hasValidLocation)
        }
    }
    
    private var expandedFiltersContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .padding(.vertical, 4)
            
            HStack {
                Text("Search Criteria")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
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
        }
    }
    
    // MARK: - Analyzing State
    
    private var analyzingContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            LoadingThreeBallsTriangle(
                color: colorScheme == .dark ? .white : .black,
                size: 60,
                speed: 0.5
            )
            
            VStack(spacing: 8) {
                Text("Analyzing the market")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Searching for investments in \(viewModel.criteria.location)...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Show filters summary during loading
            VStack(alignment: .leading, spacing: 6) {
                Text("Looking for:")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Text(viewModel.criteria.filterSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(viewModel.criteria.returnTargetsSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Results State
    
    private var resultsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if !homeViewModel.marketRateItems.isEmpty {
                    ratesAutoScrollView
                        .frame(height: 50)
                }

                if viewModel.results.isEmpty {
                    noResultsView
                } else {
                    resultsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No matching investments found")
                .font(.headline)
            
            Text("Try adjusting your filters or searching a different location.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .opacity(resultsAppeared ? 1 : 0)
    }

    private var resultsSummary: some View {
        let results = viewModel.results
        let avgCapRate = results.compactMap { $0.metrics.capRate }.average
        let avgCashOnCash = results.compactMap { $0.metrics.cashOnCash }.average
        let avgScore = results.map { $0.metrics.score }.average
        let priceRange = (
            min: results.map { $0.property.askingPrice }.min() ?? 0,
            max: results.map { $0.property.askingPrice }.max() ?? 0
        )
        
        return VStack(alignment: .leading, spacing: 16) {
            // Header with location and count
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(results.count)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("properties found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("in \(viewModel.criteria.location)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Metrics row
            HStack(spacing: 0) {
                summaryMetric(
                    value: avgCapRate.asPercentString,
                    label: "Avg Cap"
                )
                
                Spacer()
                
                summaryMetric(
                    value: avgCashOnCash.asPercentString,
                    label: "Avg CoC"
                )
                
                Spacer()
                
                summaryMetric(
                    value: String(format: "%.0f", avgScore),
                    label: "Avg Score"
                )
                
                Spacer()
                
                summaryMetric(
                    value: priceRange.min.asCompactCurrency + "–" + priceRange.max.asCompactCurrency,
                    label: "Price Range"
                )
            }
            
            Divider()
                .padding(.top, 4)
        }
        .opacity(resultsAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: resultsAppeared)
    }
    
    private func summaryMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            resultsSummary
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Matches")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .opacity(resultsAppeared ? 1 : 0)

                LazyVStack(spacing: 16) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, result in
                        investmentResultPropertyCard(for: result)
                            .opacity(resultsAppeared ? 1 : 0)
                            .offset(y: resultsAppeared ? 0 : 30)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(Double(index) * 0.05),
                                value: resultsAppeared
                            )
                    }
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Searches")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(viewModel.history) { item in
                    Button {
                        viewModel.applyHistory(item)
                        Task {
                            await viewModel.search()
                            if viewModel.errorMessage == nil {
                                try? await Task.sleep(nanoseconds: 100_000_000)
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    resultsAppeared = true
                                }
                            }
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.criteria.location)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)

                                HStack(spacing: 6) {
                                    Text("\(item.resultCount) results")
                                    Text("·")
                                    Text("Avg \(Int(item.averageScore))")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(item.searchedAt.relativeFormat)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation {
                                viewModel.deleteHistoryItem(item)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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

// MARK: - Location Search Field

/// Location search field with MapKit autocomplete for city/state/ZIP searches
struct LocationSearchField: View {
    let title: String
    @Binding var selectedLocation: String
    
    @State private var searchCompleter = LocationSearchCompleter()
    @State private var showSuggestions: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.tertiary)
                    
                    TextField("City, State, or ZIP", text: $searchCompleter.searchQuery)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .onChange(of: searchCompleter.searchQuery) { _, newValue in
                            showSuggestions = !newValue.isEmpty && isFocused
                            selectedLocation = newValue
                        }
                        .onChange(of: isFocused) { _, focused in
                            if focused {
                                showSuggestions = !searchCompleter.searchQuery.isEmpty
                                Task { @MainActor in
                                    HapticManager.shared.editField()
                                }
                            } else {
                                // Delay hiding so tap on suggestion can register
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showSuggestions = false
                                }
                            }
                        }
                    
                    if !searchCompleter.searchQuery.isEmpty {
                        Button {
                            searchCompleter.clearSearch()
                            selectedLocation = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !selectedLocation.isEmpty && !isFocused {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isFocused ? Color.accentColor : Color(.separator), lineWidth: isFocused ? 1.5 : 0.5)
                }
            }
            
            // Suggestions dropdown
            if showSuggestions && !searchCompleter.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchCompleter.suggestions.prefix(5)) { suggestion in
                        Button {
                            selectSuggestion(suggestion)
                        } label: {
                            HStack {
                                Text(suggestion.fullLocation)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if suggestion.id != searchCompleter.suggestions.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSuggestions)
        .animation(.easeInOut(duration: 0.2), value: searchCompleter.suggestions.count)
        .onAppear {
            // Sync initial value
            if !selectedLocation.isEmpty {
                searchCompleter.searchQuery = selectedLocation
            }
        }
    }
    
    private func selectSuggestion(_ suggestion: LocationSuggestion) {
        searchCompleter.searchQuery = suggestion.fullLocation
        selectedLocation = suggestion.fullLocation
        showSuggestions = false
        isFocused = false
        HapticManager.shared.selection()
    }
}

// MARK: - Location Search Completer

/// Location suggestion model for city/state/ZIP searches
struct LocationSuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion
    
    var fullLocation: String {
        if subtitle.isEmpty {
            return title
        }
        return "\(title), \(subtitle)"
    }
    
    static func == (lhs: LocationSuggestion, rhs: LocationSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

/// Observable class that handles location autocomplete for investment search
@MainActor
@Observable
final class LocationSearchCompleter: NSObject {
    var suggestions: [LocationSuggestion] = []
    var isSearching: Bool = false
    var searchQuery: String = "" {
        didSet {
            searchCompleter.queryFragment = searchQuery
        }
    }
    
    private let searchCompleter = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .query]
        searchCompleter.pointOfInterestFilter = .excludingAll
    }
    
    func clearSearch() {
        suggestions = []
        searchQuery = ""
    }
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            // Filter to prefer city/region results over specific street addresses
            self.suggestions = completer.results
                .filter { result in
                    // Prefer results that look like cities/regions (no street numbers at start)
                    let hasStreetNumber = result.title.first?.isNumber ?? false
                    return !hasStreetNumber
                }
                .map { result in
                    LocationSuggestion(
                        title: result.title,
                        subtitle: result.subtitle,
                        completion: result
                    )
                }
            self.isSearching = false
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }
}
