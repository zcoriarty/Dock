//
//  HomeView.swift
//  Dock
//
//  Main home screen with property list and market rates
//

import SwiftUI
import Charts

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showingAddProperty = false
    @State private var selectedProperty: Property?
    @State private var showingFilters = false
    @State private var showingSearch = false
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var namespace
    
    // Persisted sort preferences (defaults to Score, descending)
    @AppStorage("propertySortOption") private var storedSortOption: String = "Score"
    @AppStorage("propertySortAscending") private var storedSortAscending: Bool = false
    
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
                
                if viewModel.properties.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 0) {
                        // Auto-scrolling rates bar
                        if !viewModel.marketRateItems.isEmpty {
                            ratesAutoScrollView
                                .frame(height: 50)
                        }
                        emptyState
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Auto-scrolling rates bar
                            if !viewModel.marketRateItems.isEmpty {
                                ratesAutoScrollView
                                    .frame(height: 50)
                            }
                            
                            // Main Content
                            mainContent
                        }
                    }
                    .refreshable {
                        await viewModel.loadData()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.properties.count) \(viewModel.properties.count == 1 ? "Property" : "Properties")")
                            .font(.title2)
                            .fontWeight(.bold)

                        
                        Text(Date.now, style: .date)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                    }
                    .fixedSize(horizontal: true, vertical: true)

                }
                .sharedBackgroundVisibility(.hidden)

                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingSearch = true
                            HapticManager.shared.impact(.light)
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        
                        Menu {
                            ForEach(HomeViewModel.SortOption.allCases) { option in
                                Button {
                                    withAnimation {
                                        viewModel.sortOption = option
                                        storedSortOption = option.rawValue
                                    }
                                    HapticManager.shared.selection()
                                } label: {
                                    HStack {
                                        Image(systemName: option.icon)
                                        Text(option.rawValue)
                                        if viewModel.sortOption == option {
                                            Image(systemName: viewModel.sortAscending ? "arrow.up" : "arrow.down")
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            Button {
                                withAnimation {
                                    viewModel.sortAscending.toggle()
                                    storedSortAscending = viewModel.sortAscending
                                }
                            } label: {
                                Label(
                                    viewModel.sortAscending ? "Descending" : "Ascending",
                                    systemImage: viewModel.sortAscending ? "arrow.down" : "arrow.up"
                                )
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        
                        Button {
                            showingAddProperty = true
                            HapticManager.shared.impact(.medium)
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddProperty) {
                AddPropertyView { property in
                    Task {
                        await viewModel.addProperty(property)
                    }
                }
            }
            .navigationDestination(item: $selectedProperty) { property in
                PropertyDetailView(
                    property: property,
                    onSave: { updated in
                        Task {
                            await viewModel.updateProperty(updated)
                        }
                    }
                )
                .navigationTransition(.zoom(sourceID: property.id, in: namespace))
            }
            .onAppear {
                // Load persisted sort preferences
                if let option = HomeViewModel.SortOption(rawValue: storedSortOption) {
                    viewModel.sortOption = option
                }
                viewModel.sortAscending = storedSortAscending
            }
        }
        .searchable(text: $viewModel.searchText, isPresented: $showingSearch, prompt: "Search properties")
    }
    
    // MARK: - Rates Auto Scroll View
    
    @ViewBuilder
    private var ratesAutoScrollView: some View {
        if viewModel.marketRateItems.count > 0 {
            LoopingScrollView(
                spacing: 15,
                scrollingSpeed: 0.5,
                itemWidth: 160,
                data: viewModel.marketRateItems
            ) { item, isRepeated in
                RateItemView(item: item, showChart: true)
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        LazyVStack(spacing: 20) {
            // Folders
            if !viewModel.folders.isEmpty {
                foldersSection
            }
            
            // Properties
            propertyCards
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Folders Section
    
    private var foldersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All properties
                ModernFolderChip(
                    name: "All",
                    count: viewModel.properties.count,
                    color: .primary,
                    isSelected: viewModel.selectedFolder == nil,
                    colorScheme: colorScheme
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedFolder = nil
                    }
                }
                
                // Pinned
                if viewModel.pinnedCount > 0 {
                    ModernFolderChip(
                        name: "Pinned",
                        count: viewModel.pinnedCount,
                        color: .orange,
                        isSelected: false,
                        icon: "pin.fill",
                        colorScheme: colorScheme
                    ) {
                        // Filter to pinned
                    }
                }
                
                // Custom folders
                ForEach(viewModel.folders) { folder in
                    ModernFolderChip(
                        name: folder.name,
                        count: viewModel.properties.filter { $0.folderID == folder.id }.count,
                        color: folder.color,
                        isSelected: viewModel.selectedFolder?.id == folder.id,
                        colorScheme: colorScheme
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedFolder = folder
                        }
                    }
                }
                
                // Add folder button
                Button {
                    viewModel.showingFolderSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(cardBackground)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Property Cards
    
    private var propertyCards: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.displayedProperties) { property in
                PropertyCard(
                    property: property,
                    cardBackground: cardBackground,
                    colorScheme: colorScheme,
                    onPin: {
                        Task {
                            await viewModel.togglePin(property)
                        }
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteProperty(property)
                        }
                    }
                )
                .matchedTransitionSource(id: property.id, in: namespace)
                .onTapGesture {
                    selectedProperty = property
                    HapticManager.shared.impact(.light)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "building.2")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                    }
                
                VStack(spacing: 8) {
                    Text("No Properties Yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Add your first investment property to start analyzing deals")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Button {
                showingAddProperty = true
            } label: {
                Text("Add Property")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.primary)
                    .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
    }
}

// MARK: - Rate Item View

struct RateItemView: View {
    let item: MarketRateItem
    var showChart: Bool = false
    
    private var chartColor: Color {
        item.changePercent == 0 ? .secondary : item.changeColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text(item.value)
                    .font(.system(size: 17))
                    .fontWeight(.bold)
                
                // Only show change row if not neutral
                if item.changePercent != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: item.changeIcon)
                            .font(.caption2)
                        Text(item.change)
                            .font(.caption)
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(item.changeColor)
                }
            }
            
            if showChart && item.historicalData.count > 1 {
                Chart {
                    ForEach(0..<item.historicalData.count, id: \.self) { index in
                        let point = item.historicalData[index]
                        
                        LineMark(
                            x: .value("X", index),
                            y: .value("Y", point)
                        )
                        .foregroundStyle(chartColor)
                        
                        AreaMark(
                            x: .value("X", index),
                            y: .value("Y", point)
                        )
                        .foregroundStyle(chartColor.opacity(0.2))
                    }
                }
                .chartLegend(.hidden)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(maxWidth: 50, maxHeight: 20)
            }
        }
    }
}

// MARK: - Modern Folder Chip

struct ModernFolderChip: View {
    let name: String
    let count: Int
    let color: Color
    let isSelected: Bool
    var icon: String? = nil
    var colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .fontWeight(.medium)
                } else if !isSelected {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
                
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.7) : Color.secondary.opacity(1))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
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

// MARK: - Compact Stat

struct CompactStat: View {
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Legacy Support

struct FolderChip: View {
    let name: String
    let count: Int
    let color: Color
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                
                Text(name)
                    .font(.subheadline)
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? color : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
