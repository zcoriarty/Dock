//
//  HomeView.swift
//  Dock
//
//  Main home screen with property list
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showingAddProperty = false
    @State private var selectedProperty: Property?
    @State private var showingFilters = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundColor
                    .ignoresSafeArea()
                
                if viewModel.properties.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    mainContent
                }
            }
            .navigationTitle("\(viewModel.properties.count) Home\(viewModel.properties.count == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search properties")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(HomeViewModel.SortOption.allCases) { option in
                            Button {
                                withAnimation {
                                    viewModel.sortOption = option
                                }
                                Task { @MainActor in
                                    HapticManager.shared.selection()
                                }
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
                            }
                        } label: {
                            Label(
                                viewModel.sortAscending ? "Descending" : "Ascending",
                                systemImage: viewModel.sortAscending ? "arrow.down" : "arrow.up"
                            )
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .fontWeight(.medium)
                            .symbolVariant(viewModel.sortOption != .dateAdded ? .fill : .none)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddProperty = true
                        Task { @MainActor in
                            HapticManager.shared.impact(.medium)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
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
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Folders
                if !viewModel.folders.isEmpty {
                    foldersSection
                }
                
                // Properties
                propertyCards
            }
            .padding(.vertical, 16)
        }
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
                ModernPropertyCard(
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
                .onTapGesture {
                    selectedProperty = property
                    Task { @MainActor in
                        HapticManager.shared.impact(.light)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 32) {
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

// MARK: - Modern Property Card

struct ModernPropertyCard: View {
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
    
    private var hasImage: Bool {
        if let photoData = property.primaryPhotoData,
           UIImage(data: photoData) != nil {
            return true
        }
        return false
    }
    
    var body: some View {
        Group {
            if hasImage {
                largeCardLayout
            } else {
                compactCardLayout
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    
    // MARK: - Large Card Layout (with image)
    
    private var largeCardLayout: some View {
        VStack(spacing: 0) {
            // Image section
            ZStack(alignment: .topTrailing) {
                if let photoData = property.primaryPhotoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                }
                
                // Score badge overlay
                scoreBadge
                    .padding(12)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Price and pin
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(property.askingPrice.asCompactCurrency)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        
                        Text(property.address)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Text("\(property.city), \(property.state)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Pin indicator
                    if property.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                // Stats row
                HStack(spacing: 16) {
                    CardStat(value: "\(property.bedrooms)", label: "Beds")
                    CardStat(value: String(format: "%.1f", property.bathrooms), label: "Baths")
                    CardStat(value: property.squareFeet.withCommas, label: "Sq Ft")
                    
                    Spacer()
                    
                    cashFlowBadge
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Compact Card Layout (no image)
    
    private var compactCardLayout: some View {
        HStack(spacing: 14) {
            // Square placeholder on the left
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                
                Image(systemName: property.propertyType.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.primary.opacity(0.2))
            }
            .frame(maxWidth: 100)
            
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
        .padding(12)
    }
    
    // MARK: - Shared Components
    
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

// MARK: - Card Stat

struct CardStat: View {
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
