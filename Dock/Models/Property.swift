//
//  Property.swift
//  Dock
//
//  Investment property model with all underwriting data
//

import Foundation
import SwiftUI

// MARK: - Property Model

struct Property: Identifiable, Hashable, Sendable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    
    // Source Data (supports Zillow, Redfin, Realtor.com URLs)
    var listingURL: String?
    
    // Address
    var address: String
    var city: String
    var state: String
    var zipCode: String
    var latitude: Double?
    var longitude: Double?
    
    // Property Details
    var askingPrice: Double
    var bedrooms: Int
    var bathrooms: Double
    var squareFeet: Int
    var lotSize: Int
    var yearBuilt: Int
    var propertyType: PropertyType
    var unitCount: Int
    
    // Tax & Assessment
    var taxAssessedValue: Double
    var annualTaxes: Double
    
    // Income Estimates
    var estimatedRentPerUnit: Double
    var estimatedTotalRent: Double
    
    // Expense Assumptions
    var vacancyRate: Double
    var managementFeePercent: Double
    var repairsPerUnit: Double
    var insuranceAnnual: Double
    var otherExpenses: Double
    
    // Financing
    var financing: FinancingInputs
    
    // Thresholds
    var thresholds: InvestmentThresholds
    
    // Market Data
    var marketData: MarketData?
    
    // Calculated Metrics (computed on demand)
    var metrics: DealMetrics {
        UnderwritingEngine.calculateMetrics(for: self)
    }
    
    // Folder
    var folderID: UUID?
    
    // Photos
    var photoURLs: [String]
    var primaryPhotoData: Data?
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        listingURL: String? = nil,
        address: String = "",
        city: String = "",
        state: String = "",
        zipCode: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        askingPrice: Double = 0,
        bedrooms: Int = 0,
        bathrooms: Double = 0,
        squareFeet: Int = 0,
        lotSize: Int = 0,
        yearBuilt: Int = 0,
        propertyType: PropertyType = .singleFamily,
        unitCount: Int = 1,
        taxAssessedValue: Double = 0,
        annualTaxes: Double = 0,
        estimatedRentPerUnit: Double = 0,
        estimatedTotalRent: Double = 0,
        vacancyRate: Double = 0.05,
        managementFeePercent: Double = 0.08,
        repairsPerUnit: Double = 1200,
        insuranceAnnual: Double = 0,
        otherExpenses: Double = 0,
        financing: FinancingInputs = FinancingInputs(),
        thresholds: InvestmentThresholds = InvestmentThresholds(),
        marketData: MarketData? = nil,
        folderID: UUID? = nil,
        photoURLs: [String] = [],
        primaryPhotoData: Data? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.listingURL = listingURL
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.latitude = latitude
        self.longitude = longitude
        self.askingPrice = askingPrice
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.squareFeet = squareFeet
        self.lotSize = lotSize
        self.yearBuilt = yearBuilt
        self.propertyType = propertyType
        self.unitCount = unitCount
        self.taxAssessedValue = taxAssessedValue
        self.annualTaxes = annualTaxes
        self.estimatedRentPerUnit = estimatedRentPerUnit
        self.estimatedTotalRent = estimatedTotalRent
        self.vacancyRate = vacancyRate
        self.managementFeePercent = managementFeePercent
        self.repairsPerUnit = repairsPerUnit
        self.insuranceAnnual = insuranceAnnual
        self.otherExpenses = otherExpenses
        self.financing = financing
        self.thresholds = thresholds
        self.marketData = marketData
        self.folderID = folderID
        self.photoURLs = photoURLs
        self.primaryPhotoData = primaryPhotoData
    }
    
    var fullAddress: String {
        "\(address), \(city), \(state) \(zipCode)"
    }
    
    var pricePerSquareFoot: Double {
        guard squareFeet > 0 else { return 0 }
        return askingPrice / Double(squareFeet)
    }
    
    var pricePerUnit: Double {
        guard unitCount > 0 else { return askingPrice }
        return askingPrice / Double(unitCount)
    }
    
    /// The source of the listing (Zillow, Redfin, Realtor.com)
    var listingSource: String? {
        listingURL?.listingSource
    }
    
    /// URL to view the property listing - uses stored URL or generates Zillow search
    var viewableListingURL: URL? {
        if let listingURL = listingURL, let url = URL(string: listingURL) {
            return url
        }
        // Fallback: generate a Zillow search URL from the address
        let searchQuery = fullAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.zillow.com/homes/\(searchQuery)_rb/")
    }
}

// MARK: - Property Type

enum PropertyType: String, CaseIterable, Codable, Sendable {
    case singleFamily = "Single Family"
    case multiFamily = "Multi Family"
    case condo = "Condo"
    case townhouse = "Townhouse"
    case duplex = "Duplex"
    case triplex = "Triplex"
    case fourplex = "Fourplex"
    case apartment = "Apartment"
    case land = "Land"
    case commercial = "Commercial"
    case mobile = "Mobile"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .singleFamily: return "house.fill"
        case .multiFamily, .apartment: return "building.2.fill"
        case .condo: return "building.fill"
        case .townhouse: return "house.and.flag.fill"
        case .duplex, .triplex, .fourplex: return "square.stack.3d.up.fill"
        case .land: return "leaf.fill"
        case .commercial: return "storefront.fill"
        case .mobile: return "car.fill"
        case .other: return "questionmark.square.fill"
        }
    }
}

// MARK: - Financing Inputs

struct FinancingInputs: Hashable, Codable, Sendable {
    var purchasePrice: Double
    var loanAmount: Double
    var interestRate: Double // Annual rate as decimal (0.07 = 7%)
    var loanTermYears: Int
    var ltv: Double // Loan to value as decimal (0.75 = 75%)
    var closingCosts: Double
    var isInterestOnly: Bool
    
    init(
        purchasePrice: Double = 0,
        loanAmount: Double = 0,
        interestRate: Double = 0.07,
        loanTermYears: Int = 30,
        ltv: Double = 0.75,
        closingCosts: Double = 0,
        isInterestOnly: Bool = false
    ) {
        self.purchasePrice = purchasePrice
        self.loanAmount = loanAmount
        self.interestRate = interestRate
        self.loanTermYears = loanTermYears
        self.ltv = ltv
        self.closingCosts = closingCosts
        self.isInterestOnly = isInterestOnly
    }
    
    var downPayment: Double {
        purchasePrice - loanAmount
    }
    
    var downPaymentPercent: Double {
        guard purchasePrice > 0 else { return 0 }
        return downPayment / purchasePrice
    }
    
    var totalCashRequired: Double {
        downPayment + closingCosts
    }
    
    mutating func updateLoanFromLTV() {
        loanAmount = purchasePrice * ltv
    }
    
    mutating func updateLTVFromLoan() {
        guard purchasePrice > 0 else { return }
        ltv = loanAmount / purchasePrice
    }
}

// MARK: - Investment Thresholds

struct InvestmentThresholds: Hashable, Codable, Sendable {
    var targetCapRate: Double
    var targetCashOnCash: Double
    var targetDSCR: Double
    var maxBreakEvenOccupancy: Double
    var minRentGrowth: Double
    var maxVacancy: Double
    
    init(
        targetCapRate: Double = 0.06,
        targetCashOnCash: Double = 0.08,
        targetDSCR: Double = 1.25,
        maxBreakEvenOccupancy: Double = 0.85,
        minRentGrowth: Double = 0.02,
        maxVacancy: Double = 0.08
    ) {
        self.targetCapRate = targetCapRate
        self.targetCashOnCash = targetCashOnCash
        self.targetDSCR = targetDSCR
        self.maxBreakEvenOccupancy = maxBreakEvenOccupancy
        self.minRentGrowth = minRentGrowth
        self.maxVacancy = maxVacancy
    }
}

// MARK: - Property Folder

struct PropertyFolder: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var sortOrder: Int
    
    init(
        id: UUID = UUID(),
        name: String = "New Folder",
        colorHex: String = "#007AFF",
        createdAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}
