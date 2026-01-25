//
//  InvestmentSearch.swift
//  Dock
//
//  Models for investment search feature
//

import Foundation



struct InvestmentSearchCriteria: Hashable, Sendable, Codable {
    var location: String
    var minPrice: Double
    var maxPrice: Double
    var minBeds: Int
    var maxBeds: Int
    var minBaths: Int
    var minSqft: Int
    var maxSqft: Int
    var minLotSqft: Int
    var maxLotSqft: Int
    var minYearBuilt: Int
    var maxYearBuilt: Int
    var maxDaysOnMarket: Int
    var minCapRate: Double
    var minCashOnCash: Double
    var minDSCR: Double
    var targetCapRate: Double
    var targetCashOnCash: Double
    var targetDSCR: Double
    var interestRate: Double
    var downPaymentPercent: Double
    var closingCostPercent: Double
    var vacancyRate: Double
    var managementFeePercent: Double
    var repairsPerYear: Double
    var insuranceRate: Double
    var otherExpensesAnnual: Double
    var rentSensitivity: Double
    var limit: Int
    var pastDays: Int
    var listingType: ListingType
    var propertyType: PropertyType?
    
    /// Compact summary of key filters (excluding location)
    var filterSummary: String {
        var parts: [String] = []
        
        if minPrice > 0 || maxPrice > 0 {
            let minStr = minPrice > 0 ? minPrice.asCompactCurrency : "Any"
            let maxStr = maxPrice > 0 ? maxPrice.asCompactCurrency : "Any"
            parts.append("\(minStr)–\(maxStr)")
        }
        
        if minBeds > 0 {
            parts.append("\(minBeds)+ bd")
        }
        
        if minBaths > 0 {
            parts.append("\(minBaths)+ ba")
        }
        
        if minSqft > 0 {
            parts.append("\(minSqft.withCommas)+ sqft")
        }
        
        return parts.isEmpty ? "Default filters" : parts.joined(separator: " • ")
    }
    
    /// Returns summary of target return metrics
    var returnTargetsSummary: String {
        let cap = (targetCapRate * 100).formatted(.number.precision(.fractionLength(1)))
        let coc = (targetCashOnCash * 100).formatted(.number.precision(.fractionLength(1)))
        let dscr = targetDSCR.formatted(.number.precision(.fractionLength(2)))
        return "\(cap)% Cap • \(coc)% CoC • \(dscr) DSCR"
    }

    static var `default`: InvestmentSearchCriteria {
        InvestmentSearchCriteria(
            location: "",
            minPrice: 0,
            maxPrice: 0,
            minBeds: 0,
            maxBeds: 0,
            minBaths: 0,
            minSqft: 0,
            maxSqft: 0,
            minLotSqft: 0,
            maxLotSqft: 0,
            minYearBuilt: 0,
            maxYearBuilt: 0,
            maxDaysOnMarket: 0,
            minCapRate: 0.06,
            minCashOnCash: 0.08,
            minDSCR: 1.25,
            targetCapRate: 0.06,
            targetCashOnCash: 0.08,
            targetDSCR: 1.25,
            interestRate: 0.07,
            downPaymentPercent: 0.25,
            closingCostPercent: 0.03,
            vacancyRate: 0.05,
            managementFeePercent: 0.08,
            repairsPerYear: 1200,
            insuranceRate: 0.003,
            otherExpensesAnnual: 0,
            rentSensitivity: 0,
            limit: 50,
            pastDays: 0,
            listingType: .forSale,
            propertyType: nil
        )
    }
}

struct InvestmentSearchMetrics: Codable, Sendable {
    let estimatedRent: Double?
    let effectiveGrossIncome: Double?
    let netOperatingIncome: Double?
    let capRate: Double?
    let cashOnCash: Double?
    let dscr: Double?
    let annualCashFlow: Double?
    let annualDebtService: Double?
    let totalCashRequired: Double?
    let score: Double
}

struct InvestmentSearchResult: Identifiable, Sendable {
    let id: String
    let property: PropertyData
    let metrics: InvestmentSearchMetrics
}

struct InvestmentSearchHistoryItem: Identifiable, Sendable, Codable {
    let id: UUID
    let criteria: InvestmentSearchCriteria
    let resultCount: Int
    let averageScore: Double
    let searchedAt: Date
    
    init(id: UUID = UUID(), criteria: InvestmentSearchCriteria, resultCount: Int, averageScore: Double, searchedAt: Date) {
        self.id = id
        self.criteria = criteria
        self.resultCount = resultCount
        self.averageScore = averageScore
        self.searchedAt = searchedAt
    }
}
