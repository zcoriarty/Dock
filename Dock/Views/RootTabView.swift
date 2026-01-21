//
//  RootTabView.swift
//  Dock
//
//  App-level tab navigation
//

import SwiftUI

@MainActor
struct RootTabView: View {
    @State private var homeViewModel = HomeViewModel()
    @State private var searchText = ""
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Configure unselected icon color to modern gray
        let unselectedColor = UIColor(white: 0.5, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        appearance.inlineLayoutAppearance.normal.iconColor = unselectedColor
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        appearance.compactInlineLayoutAppearance.normal.iconColor = unselectedColor
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            Tab("Portfolio", systemImage: "building.2") {
                HomeView(viewModel: homeViewModel)
            }

            Tab("Scan", systemImage: "rectangle.and.text.magnifyingglass") {
                InvestmentSearchView(homeViewModel: homeViewModel)
            }
            
            Tab(role: .search) {
                NavigationStack {
                    PropertySearchView(viewModel: homeViewModel, searchText: $searchText)
                        .navigationTitle("Search")
                }
                .searchable(text: $searchText, prompt: "Search properties")
            }
        }
        .tint(.primary)
    }
}

// MARK: - Property Search View

struct PropertySearchView: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var searchText: String
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var namespace
    @State private var selectedProperty: Property?
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    private var filteredProperties: [Property] {
        guard !searchText.isEmpty else { return viewModel.properties }
        
        return viewModel.properties.filter {
            $0.address.localizedCaseInsensitiveContains(searchText) ||
            $0.city.localizedCaseInsensitiveContains(searchText) ||
            $0.state.localizedCaseInsensitiveContains(searchText) ||
            $0.zipCode.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Group {
            if searchText.isEmpty {
                ContentUnavailableView(
                    "Search Properties",
                    systemImage: "magnifyingglass",
                    description: Text("Search by address, city, state, or zip code")
                )
            } else if filteredProperties.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredProperties) { property in
                            SwipeablePropertyCard(
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
                                },
                                onTap: {
                                    selectedProperty = property
                                    HapticManager.shared.impact(.light)
                                }
                            )
                            .matchedTransitionSource(id: property.id, in: namespace)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
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
    }
}
