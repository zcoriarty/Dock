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
    @State private var viewMode: ViewMode = .cards
    
    enum ViewMode: String, CaseIterable {
        case cards = "Cards"
        case list = "List"
        
        var icon: String {
            switch self {
            case .cards: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.properties.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    mainContent
                }
            }
            .navigationTitle("Dock")
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
                            .symbolVariant(viewModel.sortOption != .dateAdded ? .fill : .none)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // View mode toggle
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewMode = viewMode == .cards ? .list : .cards
                            }
                            Task { @MainActor in
                                HapticManager.shared.impact(.light)
                            }
                        } label: {
                            Image(systemName: viewMode.icon)
                        }
                        
                        // Add button
                        Button {
                            showingAddProperty = true
                            Task { @MainActor in
                                HapticManager.shared.impact(.medium)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
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
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Summary header
                if !viewModel.properties.isEmpty {
                    summaryHeader
                        .padding(.horizontal)
                }
                
                // Folders
                if !viewModel.folders.isEmpty {
                    foldersSection
                }
                
                // Properties
                switch viewMode {
                case .cards:
                    propertyCards
                case .list:
                    propertyList
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Summary Header
    
    private var summaryHeader: some View {
        HStack(spacing: 12) {
            SummaryPill(
                title: "Properties",
                value: "\(viewModel.properties.count)",
                icon: "house.fill"
            )
            
            SummaryPill(
                title: "Total Value",
                value: viewModel.totalValue.asCompactCurrency,
                icon: "dollarsign.circle.fill"
            )
            
            SummaryPill(
                title: "Avg Cap",
                value: viewModel.averageCapRate.asPercent(),
                icon: "chart.line.uptrend.xyaxis"
            )
        }
    }
    
    // MARK: - Folders Section
    
    private var foldersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All properties
                FolderChip(
                    name: "All",
                    count: viewModel.properties.count,
                    color: .gray,
                    isSelected: viewModel.selectedFolder == nil
                ) {
                    withAnimation {
                        viewModel.selectedFolder = nil
                    }
                }
                
                // Pinned
                if viewModel.pinnedCount > 0 {
                    FolderChip(
                        name: "Pinned",
                        count: viewModel.pinnedCount,
                        color: .orange,
                        isSelected: false,
                        icon: "pin.fill"
                    ) {
                        // Filter to pinned
                    }
                }
                
                // Custom folders
                ForEach(viewModel.folders) { folder in
                    FolderChip(
                        name: folder.name,
                        count: viewModel.properties.filter { $0.folderID == folder.id }.count,
                        color: folder.color,
                        isSelected: viewModel.selectedFolder?.id == folder.id
                    ) {
                        withAnimation {
                            viewModel.selectedFolder = folder
                        }
                    }
                }
                
                // Add folder button
                Button {
                    viewModel.showingFolderSheet = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Property Cards
    
    private var propertyCards: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.displayedProperties) { property in
                PropertyCard(
                    property: property,
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
        .padding(.horizontal)
    }
    
    // MARK: - Property List
    
    private var propertyList: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.displayedProperties) { property in
                PropertyCompactCard(property: property)
                    .onTapGesture {
                        selectedProperty = property
                        Task { @MainActor in
                            HapticManager.shared.impact(.light)
                        }
                    }
                    .contextMenu {
                        Button {
                            Task {
                                await viewModel.togglePin(property)
                            }
                        } label: {
                            Label(
                                property.isPinned ? "Unpin" : "Pin",
                                systemImage: property.isPinned ? "pin.slash" : "pin"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteProperty(property)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("No Properties Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add your first investment property to start analyzing deals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showingAddProperty = true
            } label: {
                Label("Add Property", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Supporting Views

struct SummaryPill: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

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
