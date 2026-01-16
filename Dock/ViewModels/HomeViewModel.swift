//
//  HomeViewModel.swift
//  Dock
//
//  ViewModel for the home screen with property list management
//

import Foundation
import SwiftUI
import CoreData
import Combine

@MainActor
@Observable
final class HomeViewModel {
    // MARK: - Published Properties
    
    var properties: [Property] = []
    var folders: [PropertyFolder] = []
    var selectedFolder: PropertyFolder?
    var searchText: String = ""
    var sortOption: SortOption = .score
    var sortAscending: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var showingAddProperty: Bool = false
    var showingFolderSheet: Bool = false
    var selectedProperty: Property?
    
    // Expanded folder tracking for stacked view
    var expandedFolderIDs: Set<UUID> = []
    var newFolderName: String = ""
    var newFolderColor: String = "#007AFF"
    
    // Market Rates
    var currentRates: RateData?
    var marketRateItems: [MarketRateItem] = []
    var isLoadingRates: Bool = false
    
    // Market Summaries
    var citySummaries: [CityMarketSummary] = []
    var isLoadingMarketSummaries: Bool = false
    
    // MARK: - Filter & Sort
    
    enum SortOption: String, CaseIterable, Identifiable {
        case dateAdded = "Date Added"
        case price = "Price"
        case yield = "Yield (CoC)"
        case capRate = "Cap Rate"
        case location = "Location"
        case score = "Score"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .dateAdded: return "calendar"
            case .price: return "dollarsign.circle"
            case .yield: return "percent"
            case .capRate: return "chart.line.uptrend.xyaxis"
            case .location: return "mappin.circle"
            case .score: return "star.circle"
            }
        }
    }
    
    struct TrackedCity: Identifiable, Hashable, Sendable {
        let city: String
        let state: String
        let propertyCount: Int
        
        var id: String {
            "\(city.lowercased())-\(state.lowercased())"
        }
    }
    
    // MARK: - Computed Properties
    
    var displayedProperties: [Property] {
        var result = properties
        
        // Filter by folder
        if let folder = selectedFolder {
            result = result.filter { $0.folderID == folder.id }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            result = result.filter {
                $0.address.localizedCaseInsensitiveContains(searchText) ||
                $0.city.localizedCaseInsensitiveContains(searchText) ||
                $0.state.localizedCaseInsensitiveContains(searchText) ||
                $0.zipCode.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        result = sortProperties(result)
        
        // Pinned first
        let pinned = result.filter { $0.isPinned }
        let unpinned = result.filter { !$0.isPinned }
        
        return pinned + unpinned
    }
    
    var pinnedCount: Int {
        properties.filter { $0.isPinned }.count
    }
    
    var totalValue: Double {
        properties.reduce(0) { $0 + $1.askingPrice }
    }
    
    var averageCapRate: Double {
        let capRates = properties.compactMap { $0.metrics.dealEconomics.inPlaceCapRate }
        guard !capRates.isEmpty else { return 0 }
        return capRates.reduce(0, +) / Double(capRates.count)
    }
    
    var trackedCities: [TrackedCity] {
        let filtered = properties.filter { !$0.city.isBlank && !$0.state.isBlank }
        let grouped = Dictionary(grouping: filtered) { property in
            let normalizedCity = normalizedCityName(city: property.city, state: property.state)
            return "\(normalizedCity.lowercased())|\(property.state.lowercased())"
        }
        
        return grouped.compactMap { _, group in
            guard let first = group.first else { return nil }
            let normalizedCity = normalizedCityName(city: first.city, state: first.state)
            return TrackedCity(city: normalizedCity, state: first.state, propertyCount: group.count)
        }
        .sorted { $0.propertyCount > $1.propertyCount }
    }
    
    private func normalizedCityName(city: String, state: String) -> String {
        let trimmedCity = city.trimmed
        let normalizedCity = trimmedCity.lowercased()
        let normalizedState = state.trimmed.lowercased()
        
        let metroAliases: [String: [String: String]] = [
            "mi": [
                "kentwood": "Grand Rapids",
                "ada": "Grand Rapids",
                "rockford": "Grand Rapids"
            ]
        ]
        
        if let stateAliases = metroAliases[normalizedState],
           let alias = stateAliases[normalizedCity] {
            return alias
        }
        
        return trimmedCity
    }
    
    
    // MARK: - Dependencies
    
    private let viewContext: NSManagedObjectContext
    
    // MARK: - Init
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        Task {
            await loadData()
        }
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        await loadProperties()
        await loadMarketSummaries()
        await loadFolders()
        await loadRates()
    }
    
    func loadRates() async {
        isLoadingRates = true
        defer { isLoadingRates = false }
        
        do {
            let rates = try await RateService.shared.fetchCurrentRates()
            currentRates = rates
            marketRateItems = rates.toMarketRateItems()
        } catch {
            // Use fallback rates if fetch fails
            let fallback = RateData.fallbackRates
            currentRates = fallback
            marketRateItems = fallback.toMarketRateItems()
        }
    }
    
    func loadMarketSummaries() async {
        let tracked = trackedCities
        guard !tracked.isEmpty else {
            citySummaries = []
            return
        }
        
        isLoadingMarketSummaries = true
        defer { isLoadingMarketSummaries = false }
        
        var summaries: [CityMarketSummary] = []
        
        await withTaskGroup(of: CityMarketSummary?.self) { group in
            for trackedCity in tracked {
                group.addTask {
                    do {
                        let response = try await MarketSummaryService.shared.fetchCitySummary(
                            city: trackedCity.city,
                            state: trackedCity.state
                        )
                        
                        return CityMarketSummary(
                            city: response.city,
                            state: response.state,
                            averageRent: response.averageRent,
                            medianRent: response.medianRent,
                            newListingsLastWeek: response.newListingsLastWeek,
                            sampleSize: response.sampleSize,
                            source: response.source,
                            fetchedAt: Date(),
                            propertyCount: trackedCity.propertyCount
                        )
                    } catch {
                        return CityMarketSummary(
                            city: trackedCity.city,
                            state: trackedCity.state,
                            averageRent: nil,
                            medianRent: nil,
                            newListingsLastWeek: nil,
                            sampleSize: nil,
                            source: nil,
                            fetchedAt: Date(),
                            propertyCount: trackedCity.propertyCount
                        )
                    }
                }
            }
            
            for await summary in group {
                if let summary {
                    summaries.append(summary)
                }
            }
        }
        
        citySummaries = summaries.sorted { $0.propertyCount > $1.propertyCount }
    }
    
    private func loadProperties() async {
        let request: NSFetchRequest<PropertyEntity> = PropertyEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PropertyEntity.createdAt, ascending: false)]
        
        do {
            let entities = try viewContext.fetch(request)
            properties = entities.compactMap { mapEntityToProperty($0) }
        } catch {
            errorMessage = "Failed to load properties: \(error.localizedDescription)"
        }
    }
    
    private func loadFolders() async {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FolderEntity.sortOrder, ascending: true)]
        
        do {
            let entities = try viewContext.fetch(request)
            folders = entities.map { mapEntityToFolder($0) }
        } catch {
            errorMessage = "Failed to load folders: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Property Actions
    
    func addProperty(_ property: Property) async {
        let entity = PropertyEntity(context: viewContext)
        mapPropertyToEntity(property, entity: entity)
        
        do {
            try viewContext.save()
            properties.insert(property, at: 0)
            HapticManager.shared.propertyAdded()
            await loadMarketSummaries()
        } catch {
            errorMessage = "Failed to save property: \(error.localizedDescription)"
        }
    }
    
    func updateProperty(_ property: Property) async {
        let request: NSFetchRequest<PropertyEntity> = PropertyEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", property.id as CVarArg)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                mapPropertyToEntity(property, entity: entity)
                try viewContext.save()
                
                if let index = properties.firstIndex(where: { $0.id == property.id }) {
                    properties[index] = property
                }
                await loadMarketSummaries()
            }
        } catch {
            errorMessage = "Failed to update property: \(error.localizedDescription)"
        }
    }
    
    func deleteProperty(_ property: Property) async {
        let request: NSFetchRequest<PropertyEntity> = PropertyEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", property.id as CVarArg)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                try viewContext.save()
                properties.removeAll { $0.id == property.id }
                HapticManager.shared.notification(.success)
                await loadMarketSummaries()
            }
        } catch {
            errorMessage = "Failed to delete property: \(error.localizedDescription)"
        }
    }
    
    func togglePin(_ property: Property) async {
        var updated = property
        updated.isPinned.toggle()
        await updateProperty(updated)
        HapticManager.shared.toggle()
    }
    
    func moveToFolder(_ property: Property, folder: PropertyFolder?) async {
        var updated = property
        updated.folderID = folder?.id
        await updateProperty(updated)
        HapticManager.shared.impact(.medium)
    }
    
    // MARK: - Folder Actions
    
    func createFolder(name: String, colorHex: String = "#007AFF") async {
        let folder = PropertyFolder(name: name, colorHex: colorHex)
        
        let entity = FolderEntity(context: viewContext)
        entity.id = folder.id
        entity.name = folder.name
        entity.colorHex = folder.colorHex
        entity.createdAt = folder.createdAt
        entity.sortOrder = Int16(folders.count)
        
        do {
            try viewContext.save()
            folders.append(folder)
            HapticManager.shared.success()
        } catch {
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
        }
    }
    
    func deleteFolder(_ folder: PropertyFolder) async {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", folder.id as CVarArg)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                // Move properties out of folder first
                for property in properties where property.folderID == folder.id {
                    await moveToFolder(property, folder: nil)
                }
                
                viewContext.delete(entity)
                try viewContext.save()
                folders.removeAll { $0.id == folder.id }
                
                if selectedFolder?.id == folder.id {
                    selectedFolder = nil
                }
                
                // Remove from expanded set if needed
                expandedFolderIDs.remove(folder.id)
            }
        } catch {
            errorMessage = "Failed to delete folder: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Folder Expansion
    
    func toggleFolderExpansion(_ folder: PropertyFolder) {
        if expandedFolderIDs.contains(folder.id) {
            expandedFolderIDs.remove(folder.id)
        } else {
            expandedFolderIDs.insert(folder.id)
        }
        HapticManager.shared.impact(.light)
    }
    
    func isFolderExpanded(_ folder: PropertyFolder) -> Bool {
        expandedFolderIDs.contains(folder.id)
    }
    
    func propertiesInFolder(_ folder: PropertyFolder) -> [Property] {
        let folderProperties = properties.filter { $0.folderID == folder.id }
        return sortProperties(folderProperties)
    }
    
    func propertiesWithoutFolder() -> [Property] {
        let unfolderedProperties = properties.filter { $0.folderID == nil }
        return sortProperties(unfolderedProperties)
    }
    
    // MARK: - Sorting
    
    private func sortProperties(_ properties: [Property]) -> [Property] {
        let sorted: [Property]
        
        switch sortOption {
        case .dateAdded:
            sorted = properties.sorted { $0.createdAt > $1.createdAt }
        case .price:
            sorted = properties.sorted { $0.askingPrice > $1.askingPrice }
        case .yield:
            sorted = properties.sorted { $0.metrics.dealEconomics.cashOnCashReturn > $1.metrics.dealEconomics.cashOnCashReturn }
        case .capRate:
            sorted = properties.sorted { $0.metrics.dealEconomics.inPlaceCapRate > $1.metrics.dealEconomics.inPlaceCapRate }
        case .location:
            sorted = properties.sorted { $0.city < $1.city }
        case .score:
            sorted = properties.sorted { $0.metrics.overallScore > $1.metrics.overallScore }
        }
        
        return sortAscending ? sorted.reversed() : sorted
    }
    
    // MARK: - Entity Mapping
    
    private func mapEntityToProperty(_ entity: PropertyEntity) -> Property {
        let checklist: PropertyChecklist = {
            guard let data = entity.checklistData else {
                return PropertyChecklist.defaultChecklist
            }
            return (try? JSONDecoder().decode(PropertyChecklist.self, from: data))
                ?? PropertyChecklist.defaultChecklist
        }()
        return Property(
            id: entity.id ?? UUID(),
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            isPinned: entity.isPinned,
            listingURL: entity.zillowURL,
            address: entity.address ?? "",
            city: entity.city ?? "",
            state: entity.state ?? "",
            zipCode: entity.zipCode ?? "",
            latitude: entity.latitude,
            longitude: entity.longitude,
            askingPrice: entity.askingPrice,
            bedrooms: Int(entity.bedrooms),
            bathrooms: entity.bathrooms,
            squareFeet: Int(entity.squareFeet),
            lotSize: Int(entity.lotSize),
            yearBuilt: Int(entity.yearBuilt),
            propertyType: PropertyType(rawValue: entity.propertyType ?? "") ?? .singleFamily,
            unitCount: Int(entity.unitCount),
            taxAssessedValue: entity.taxAssessedValue,
            annualTaxes: entity.annualTaxes,
            estimatedRentPerUnit: entity.estimatedRentPerUnit,
            estimatedTotalRent: entity.estimatedTotalRent,
            vacancyRate: entity.vacancyRate,
            managementFeePercent: entity.managementFeePercent,
            repairsPerUnit: entity.repairsPerUnit,
            insuranceAnnual: entity.insuranceAnnual,
            otherExpenses: entity.otherExpenses,
            financing: FinancingInputs(
                purchasePrice: entity.askingPrice,
                loanAmount: entity.loanAmount,
                interestRate: entity.interestRate,
                loanTermYears: Int(entity.loanTermYears),
                ltv: entity.ltv,
                closingCosts: entity.closingCosts
            ),
            thresholds: InvestmentThresholds(
                targetCapRate: entity.targetCapRate,
                targetCashOnCash: entity.targetCashOnCash,
                targetDSCR: entity.targetDSCR
            ),
            marketData: MarketData(
                rentGrowthYoY: entity.marketRentGrowth,
                priceAppreciationYoY: entity.marketPriceAppreciation,
                vacancyRate: entity.marketVacancy,
                daysOnMarket: Int(entity.marketDOM)
            ),
            checklist: checklist,
            folderID: entity.folder?.id,
            photoURLs: entity.photoURLs as? [String] ?? [],
            primaryPhotoData: entity.primaryPhotoData
        )
    }
    
    private func mapPropertyToEntity(_ property: Property, entity: PropertyEntity) {
        entity.id = property.id
        entity.createdAt = property.createdAt
        entity.updatedAt = Date()
        entity.isPinned = property.isPinned
        entity.zillowURL = property.listingURL
        entity.address = property.address
        entity.city = property.city
        entity.state = property.state
        entity.zipCode = property.zipCode
        entity.latitude = property.latitude ?? 0
        entity.longitude = property.longitude ?? 0
        entity.askingPrice = property.askingPrice
        entity.bedrooms = Int16(property.bedrooms)
        entity.bathrooms = property.bathrooms
        entity.squareFeet = Int32(property.squareFeet)
        entity.lotSize = Int32(property.lotSize)
        entity.yearBuilt = Int16(property.yearBuilt)
        entity.propertyType = property.propertyType.rawValue
        entity.unitCount = Int16(property.unitCount)
        entity.taxAssessedValue = property.taxAssessedValue
        entity.annualTaxes = property.annualTaxes
        entity.estimatedRentPerUnit = property.estimatedRentPerUnit
        entity.estimatedTotalRent = property.estimatedTotalRent
        entity.vacancyRate = property.vacancyRate
        entity.managementFeePercent = property.managementFeePercent
        entity.repairsPerUnit = property.repairsPerUnit
        entity.insuranceAnnual = property.insuranceAnnual
        entity.otherExpenses = property.otherExpenses
        entity.loanAmount = property.financing.loanAmount
        entity.interestRate = property.financing.interestRate
        entity.loanTermYears = Int16(property.financing.loanTermYears)
        entity.ltv = property.financing.ltv
        entity.closingCosts = property.financing.closingCosts
        entity.targetCapRate = property.thresholds.targetCapRate
        entity.targetCashOnCash = property.thresholds.targetCashOnCash
        entity.targetDSCR = property.thresholds.targetDSCR
        entity.marketRentGrowth = property.marketData?.rentGrowthYoY ?? 0
        entity.marketPriceAppreciation = property.marketData?.priceAppreciationYoY ?? 0
        entity.marketVacancy = property.marketData?.vacancyRate ?? 0
        entity.marketDOM = Int16(property.marketData?.daysOnMarket ?? 0)
        entity.overallScore = property.metrics.overallScore
        entity.recommendation = property.metrics.recommendation.rawValue
        entity.photoURLs = property.photoURLs as NSArray
        entity.primaryPhotoData = property.primaryPhotoData
        entity.checklistData = try? JSONEncoder().encode(property.checklist)
        
        // Set folder relationship
        if let folderID = property.folderID {
            let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
            folderRequest.predicate = NSPredicate(format: "id == %@", folderID as CVarArg)
            if let folderEntity = try? viewContext.fetch(folderRequest).first {
                entity.folder = folderEntity
            }
        } else {
            entity.folder = nil
        }
    }
    
    private func mapEntityToFolder(_ entity: FolderEntity) -> PropertyFolder {
        PropertyFolder(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            colorHex: entity.colorHex ?? "#007AFF",
            createdAt: entity.createdAt ?? Date(),
            sortOrder: Int(entity.sortOrder)
        )
    }
}
