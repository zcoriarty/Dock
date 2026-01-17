//
//  InvestmentSearchViewModel.swift
//  Dock
//
//  ViewModel for investment search feature
//

import Foundation
import CoreData
import SwiftUI

@MainActor
@Observable
final class InvestmentSearchViewModel {
    var criteria: InvestmentSearchCriteria = .default {
        didSet {
            saveCriteriaToStorage()
        }
    }
    var results: [InvestmentSearchResult] = []
    var history: [InvestmentSearchHistoryItem] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    /// Search phase for UI state management
    enum SearchPhase: Equatable {
        case idle
        case analyzing
        case complete
    }
    var searchPhase: SearchPhase = .idle

    private let propertyService = PropertyDataService.shared
    private let persistenceController = PersistenceController.shared
    
    // MARK: - AppStorage Keys
    private static let criteriaStorageKey = "investmentSearchCriteria"
    
    init() {
        loadCriteriaFromStorage()
        loadHistoryFromCoreData()
    }
    
    // MARK: - Persistence
    
    private func loadCriteriaFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: Self.criteriaStorageKey),
              let savedCriteria = try? JSONDecoder().decode(InvestmentSearchCriteria.self, from: data) else {
            return
        }
        // Load saved criteria but clear location for fresh search
        var loadedCriteria = savedCriteria
        loadedCriteria.location = ""
        criteria = loadedCriteria
    }
    
    private func saveCriteriaToStorage() {
        guard let data = try? JSONEncoder().encode(criteria) else { return }
        UserDefaults.standard.set(data, forKey: Self.criteriaStorageKey)
    }
    
    private func loadHistoryFromCoreData() {
        let context = persistenceController.container.viewContext
        let request = NSFetchRequest<InvestmentSearchHistoryEntity>(entityName: "InvestmentSearchHistoryEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \InvestmentSearchHistoryEntity.searchedAt, ascending: false)]
        request.fetchLimit = 10
        
        do {
            let entities = try context.fetch(request)
            history = entities.compactMap { entity -> InvestmentSearchHistoryItem? in
                guard let id = entity.id,
                      let criteriaData = entity.criteriaData,
                      let savedCriteria = try? JSONDecoder().decode(InvestmentSearchCriteria.self, from: criteriaData),
                      let searchedAt = entity.searchedAt else {
                    return nil
                }
                return InvestmentSearchHistoryItem(
                    id: id,
                    criteria: savedCriteria,
                    resultCount: Int(entity.resultCount),
                    averageScore: entity.averageScore,
                    searchedAt: searchedAt
                )
            }
        } catch {
            print("Failed to load search history: \(error)")
        }
    }
    
    private func saveHistoryToCoreData(_ item: InvestmentSearchHistoryItem) {
        let context = persistenceController.container.viewContext
        
        let entity = InvestmentSearchHistoryEntity(context: context)
        entity.id = item.id
        entity.location = item.criteria.location
        entity.criteriaData = try? JSONEncoder().encode(item.criteria)
        entity.resultCount = Int16(item.resultCount)
        entity.averageScore = item.averageScore
        entity.searchedAt = item.searchedAt
        
        // Limit history to 10 items
        let request = NSFetchRequest<InvestmentSearchHistoryEntity>(entityName: "InvestmentSearchHistoryEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \InvestmentSearchHistoryEntity.searchedAt, ascending: false)]
        
        do {
            let allItems = try context.fetch(request)
            if allItems.count > 10 {
                for item in allItems.suffix(from: 10) {
                    context.delete(item)
                }
            }
            persistenceController.save()
        } catch {
            print("Failed to save search history: \(error)")
        }
    }
    
    func deleteHistoryItem(_ item: InvestmentSearchHistoryItem) {
        let context = persistenceController.container.viewContext
        let request = NSFetchRequest<InvestmentSearchHistoryEntity>(entityName: "InvestmentSearchHistoryEntity")
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            entities.forEach { context.delete($0) }
            persistenceController.save()
            history.removeAll { $0.id == item.id }
        } catch {
            print("Failed to delete history item: \(error)")
        }
    }

    func search() async {
        let trimmedLocation = criteria.location.trimmed
        guard !trimmedLocation.isEmpty else {
            errorMessage = "Enter a city, state, or ZIP code to search."
            HapticManager.shared.warning()
            return
        }

        searchPhase = .analyzing
        isLoading = true
        results = [] // Clear previous results
        
        defer {
            isLoading = false
        }

        do {
            criteria.location = trimmedLocation
            let request = criteria
            let fetchedResults = try await propertyService.searchInvestmentProperties(criteria: request)
            
            // Small delay to ensure loading animation is visible
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            self.results = fetchedResults.sorted { $0.metrics.score > $1.metrics.score }

            let averageScore = fetchedResults.isEmpty
                ? 0
                : fetchedResults.map { $0.metrics.score }.reduce(0, +) / Double(fetchedResults.count)

            let historyItem = InvestmentSearchHistoryItem(
                criteria: request,
                resultCount: fetchedResults.count,
                averageScore: averageScore,
                searchedAt: Date()
            )

            // Only add to history if this exact criteria hasn't been searched recently
            if !history.contains(where: { $0.criteria == request }) {
                history.insert(historyItem, at: 0)
                if history.count > 10 {
                    history.removeLast(history.count - 10)
                }

                saveHistoryToCoreData(historyItem)
            }

            errorMessage = nil
            searchPhase = .complete
            HapticManager.shared.success()
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            searchPhase = .idle
            HapticManager.shared.error()
        }
    }

    func applyHistory(_ item: InvestmentSearchHistoryItem) {
        criteria = item.criteria
    }

    func resetCriteria() {
        let location = criteria.location
        criteria = .default
        criteria.location = location
    }
    
    func resetSearch() {
        searchPhase = .idle
        results = []
    }

    func propertyForTracking(from result: InvestmentSearchResult) -> Property {
        let price = result.property.askingPrice
        let monthlyRent = result.metrics.estimatedRent ?? 0

        var property = Property(
            listingURL: result.property.listingURL,
            address: result.property.address,
            city: result.property.city,
            state: result.property.state,
            zipCode: result.property.zipCode,
            latitude: result.property.latitude,
            longitude: result.property.longitude,
            askingPrice: price,
            bedrooms: result.property.bedrooms,
            bathrooms: result.property.bathrooms,
            squareFeet: result.property.squareFeet,
            lotSize: result.property.lotSize,
            yearBuilt: result.property.yearBuilt,
            propertyType: result.property.propertyType,
            taxAssessedValue: result.property.taxAssessedValue,
            annualTaxes: result.property.annualTaxes,
            estimatedRentPerUnit: monthlyRent,
            estimatedTotalRent: monthlyRent,
            vacancyRate: criteria.vacancyRate,
            managementFeePercent: criteria.managementFeePercent,
            repairsPerUnit: criteria.repairsPerYear,
            insuranceAnnual: price * criteria.insuranceRate,
            otherExpenses: criteria.otherExpensesAnnual,
            financing: FinancingInputs(
                purchasePrice: price,
                loanAmount: price * (1 - criteria.downPaymentPercent),
                interestRate: criteria.interestRate,
                loanTermYears: 30,
                ltv: 1 - criteria.downPaymentPercent,
                closingCosts: price * criteria.closingCostPercent
            ),
            photoURLs: result.property.photoURLs
        )

        property.unitCount = 1
        return property
    }
}
