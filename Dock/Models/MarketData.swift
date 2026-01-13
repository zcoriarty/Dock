//
//  MarketData.swift
//  Dock
//
//  Market-level indicators from data providers
//

import Foundation

// MARK: - Market Data

struct MarketData: Hashable, Codable, Sendable {
    var fetchedAt: Date
    var source: String
    
    // Rent Market
    var medianRent: Double?
    var rentGrowthYoY: Double? // Year over year as decimal
    var rentPerSquareFoot: Double?
    
    // Sales Market
    var medianHomePrice: Double?
    var priceAppreciationYoY: Double?
    var pricePerSquareFoot: Double?
    
    // Market Dynamics
    var vacancyRate: Double?
    var daysOnMarket: Int?
    var inventoryMonths: Double?
    var absorptionRate: Double?
    
    // Demographics (from Census API)
    var population: Int?
    var medianHouseholdIncome: Double?
    var populationGrowth: Double?
    var incomeGrowth: Double?
    var employmentGrowth: Double?
    
    // Supply
    var permitsYoY: Double?
    var newConstructionUnits: Int?
    
    init(
        fetchedAt: Date = Date(),
        source: String = "",
        medianRent: Double? = nil,
        rentGrowthYoY: Double? = nil,
        rentPerSquareFoot: Double? = nil,
        medianHomePrice: Double? = nil,
        priceAppreciationYoY: Double? = nil,
        pricePerSquareFoot: Double? = nil,
        vacancyRate: Double? = nil,
        daysOnMarket: Int? = nil,
        inventoryMonths: Double? = nil,
        absorptionRate: Double? = nil,
        population: Int? = nil,
        medianHouseholdIncome: Double? = nil,
        populationGrowth: Double? = nil,
        incomeGrowth: Double? = nil,
        employmentGrowth: Double? = nil,
        permitsYoY: Double? = nil,
        newConstructionUnits: Int? = nil
    ) {
        self.fetchedAt = fetchedAt
        self.source = source
        self.medianRent = medianRent
        self.rentGrowthYoY = rentGrowthYoY
        self.rentPerSquareFoot = rentPerSquareFoot
        self.medianHomePrice = medianHomePrice
        self.priceAppreciationYoY = priceAppreciationYoY
        self.pricePerSquareFoot = pricePerSquareFoot
        self.vacancyRate = vacancyRate
        self.daysOnMarket = daysOnMarket
        self.inventoryMonths = inventoryMonths
        self.absorptionRate = absorptionRate
        self.population = population
        self.medianHouseholdIncome = medianHouseholdIncome
        self.populationGrowth = populationGrowth
        self.incomeGrowth = incomeGrowth
        self.employmentGrowth = employmentGrowth
        self.permitsYoY = permitsYoY
        self.newConstructionUnits = newConstructionUnits
    }
}

// MARK: - Rent Comp

struct RentComp: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let address: String
    let distance: Double // miles
    let rent: Double
    let bedrooms: Int
    let bathrooms: Double
    let squareFeet: Int
    let rentPerSquareFoot: Double
    let daysOnMarket: Int?
    let listDate: Date?
    let source: String
    
    init(
        id: UUID = UUID(),
        address: String,
        distance: Double,
        rent: Double,
        bedrooms: Int,
        bathrooms: Double,
        squareFeet: Int,
        daysOnMarket: Int? = nil,
        listDate: Date? = nil,
        source: String = ""
    ) {
        self.id = id
        self.address = address
        self.distance = distance
        self.rent = rent
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.squareFeet = squareFeet
        self.rentPerSquareFoot = squareFeet > 0 ? rent / Double(squareFeet) : 0
        self.daysOnMarket = daysOnMarket
        self.listDate = listDate
        self.source = source
    }
}

// MARK: - Rate Data

struct RateData: Hashable, Codable, Sendable {
    var fetchedAt: Date
    var source: String
    
    // Mortgage Rates
    var rate30YrFixed: Double?
    var rate15YrFixed: Double?
    var rate5_1ARM: Double?
    var rate7_1ARM: Double?
    
    // Commercial Rates
    var primerate: Double?
    var sofr: Double?
    var treasuryRate10Yr: Double?
    
    init(
        fetchedAt: Date = Date(),
        source: String = "",
        rate30YrFixed: Double? = nil,
        rate15YrFixed: Double? = nil,
        rate5_1ARM: Double? = nil,
        rate7_1ARM: Double? = nil,
        primerate: Double? = nil,
        sofr: Double? = nil,
        treasuryRate10Yr: Double? = nil
    ) {
        self.fetchedAt = fetchedAt
        self.source = source
        self.rate30YrFixed = rate30YrFixed
        self.rate15YrFixed = rate15YrFixed
        self.rate5_1ARM = rate5_1ARM
        self.rate7_1ARM = rate7_1ARM
        self.primerate = primerate
        self.sofr = sofr
        self.treasuryRate10Yr = treasuryRate10Yr
    }
}

// MARK: - Tax Assessment

struct TaxAssessment: Hashable, Codable, Sendable {
    var fetchedAt: Date
    var source: String
    var year: Int
    var assessedValue: Double
    var landValue: Double
    var improvementValue: Double
    var taxAmount: Double
    var taxRate: Double
    
    init(
        fetchedAt: Date = Date(),
        source: String = "",
        year: Int = Calendar.current.component(.year, from: Date()),
        assessedValue: Double = 0,
        landValue: Double = 0,
        improvementValue: Double = 0,
        taxAmount: Double = 0,
        taxRate: Double = 0
    ) {
        self.fetchedAt = fetchedAt
        self.source = source
        self.year = year
        self.assessedValue = assessedValue
        self.landValue = landValue
        self.improvementValue = improvementValue
        self.taxAmount = taxAmount
        self.taxRate = taxRate
    }
}

// MARK: - Insurance Estimate

struct InsuranceEstimate: Hashable, Codable, Sendable {
    var fetchedAt: Date
    var source: String
    var annualPremium: Double
    var coverage: Double
    var deductible: Double
    var isFloodZone: Bool
    var floodInsurance: Double?
    
    init(
        fetchedAt: Date = Date(),
        source: String = "",
        annualPremium: Double = 0,
        coverage: Double = 0,
        deductible: Double = 0,
        isFloodZone: Bool = false,
        floodInsurance: Double? = nil
    ) {
        self.fetchedAt = fetchedAt
        self.source = source
        self.annualPremium = annualPremium
        self.coverage = coverage
        self.deductible = deductible
        self.isFloodZone = isFloodZone
        self.floodInsurance = floodInsurance
    }
    
    var totalAnnualCost: Double {
        annualPremium + (floodInsurance ?? 0)
    }
}
