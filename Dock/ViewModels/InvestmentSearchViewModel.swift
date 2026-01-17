//
//  InvestmentSearchViewModel.swift
//  Dock
//
//  ViewModel for investment search feature
//

import Foundation

@MainActor
@Observable
final class InvestmentSearchViewModel {
    var criteria: InvestmentSearchCriteria = .default
    var results: [InvestmentSearchResult] = []
    var history: [InvestmentSearchHistoryItem] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let propertyService = PropertyDataService.shared

    func search() async {
        let trimmedLocation = criteria.location.trimmed
        guard !trimmedLocation.isEmpty else {
            errorMessage = "Enter a city, state, or ZIP code to search."
            HapticManager.shared.warning()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            criteria.location = trimmedLocation
            let request = criteria
            let results = try await propertyService.searchInvestmentProperties(criteria: request)
            self.results = results.sorted { $0.metrics.score > $1.metrics.score }

            let averageScore = results.isEmpty
                ? 0
                : results.map { $0.metrics.score }.reduce(0, +) / Double(results.count)

            let historyItem = InvestmentSearchHistoryItem(
                criteria: request,
                resultCount: results.count,
                averageScore: averageScore,
                searchedAt: Date()
            )

            history.insert(historyItem, at: 0)
            if history.count > 10 {
                history.removeLast(history.count - 10)
            }

            errorMessage = nil
            HapticManager.shared.success()
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            HapticManager.shared.error()
        }
    }

    func applyHistory(_ item: InvestmentSearchHistoryItem) {
        criteria = item.criteria
    }

    func resetCriteria() {
        criteria = .default
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
