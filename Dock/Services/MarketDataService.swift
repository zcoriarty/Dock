//
//  MarketDataService.swift
//  Dock
//
//  Service for fetching market-level indicators using Dock API
//

import Foundation

actor MarketDataService {
    static let shared = MarketDataService()
    
    private init() {}
    
    // MARK: - Fetch Market Data
    
    func fetchMarketData(city: String, state: String, zipCode: String) async throws -> MarketData {
        // Fetch data from multiple sources in parallel
        async let housingTask = fetchHousingMarketData(city: city, state: state)
        async let censusTask = fetchCensusData(zipCode: zipCode)
        
        let housingData = try await housingTask
        let censusData = try await censusTask
        
        // Estimate rent market data based on regional averages
        let rentData = estimateRentMarketData(state: state)
        
        return MarketData(
            fetchedAt: Date(),
            source: "Dock API + Census",
            medianRent: rentData.medianRent,
            rentGrowthYoY: rentData.rentGrowth,
            rentPerSquareFoot: rentData.rentPerSqFt,
            medianHomePrice: housingData.medianPrice,
            priceAppreciationYoY: housingData.priceGrowth,
            pricePerSquareFoot: housingData.pricePerSqFt,
            vacancyRate: rentData.vacancyRate ?? 0.05,
            daysOnMarket: housingData.daysOnMarket,
            inventoryMonths: housingData.inventoryMonths,
            absorptionRate: nil,
            population: censusData.population,
            medianHouseholdIncome: censusData.medianIncome,
            populationGrowth: censusData.populationGrowth,
            incomeGrowth: censusData.incomeGrowth,
            employmentGrowth: nil,
            permitsYoY: nil,
            newConstructionUnits: nil
        )
    }
    
    // MARK: - Housing Market Data (via Dock API / HomeHarvest)
    
    private func fetchHousingMarketData(city: String, state: String) async throws -> HousingMarketResult {
        guard let baseURL = APIConfiguration.DockAPI.baseURL,
              !baseURL.isEmpty else {
            return HousingMarketResult.estimateForState(state)
        }
        
        let location = "\(city), \(state)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "\(baseURL)/search?location=\(location)&listing_type=for_sale&limit=50") else {
            throw NetworkError.invalidURL
        }
        
        print("📈 [MarketDataService] Fetching listings from: \(url.absoluteString)")
        
        do {
            let response: DockMarketSearchResponse = try await NetworkManager.shared.request(
                url: url,
                cacheKey: "housing_market_\(city)_\(state)"
            )
            
            print("📈 [MarketDataService] Got \(response.count) listings for market analysis")
            
            // Calculate market metrics from search results
            let prices = response.properties.compactMap { $0.price }
            let medianPrice = prices.isEmpty ? nil : prices.sorted()[prices.count / 2]
            
            let daysOnMarket = response.properties.compactMap { $0.daysOnMls }
            let avgDOM = daysOnMarket.isEmpty ? nil : daysOnMarket.reduce(0, +) / daysOnMarket.count
            
            let sqftPrices = response.properties.compactMap { $0.pricePerSqft }
            let avgPricePerSqft = sqftPrices.isEmpty ? nil : sqftPrices.reduce(0, +) / Double(sqftPrices.count)
            
            return HousingMarketResult(
                medianPrice: medianPrice,
                priceGrowth: nil, // Would need historical data
                pricePerSqFt: avgPricePerSqft,
                daysOnMarket: avgDOM,
                inventoryMonths: nil
            )
        } catch {
            print("⚠️ [MarketDataService] Error fetching market data: \(error.localizedDescription)")
            return HousingMarketResult.estimateForState(state)
        }
    }
    
    // MARK: - Rent Market Data (Local Estimates)
    
    private func estimateRentMarketData(state: String) -> RentMarketResult {
        // Regional averages based on state
        let (medianRent, rentPerSqFt, vacancyRate): (Double, Double, Double) = {
            switch state.uppercased() {
            // High cost states
            case "CA":
                return (2800, 2.80, 0.04)
            case "NY":
                return (2600, 2.60, 0.035)
            case "MA", "WA", "NJ":
                return (2400, 2.30, 0.04)
            case "CO", "OR", "MD", "VA":
                return (2100, 2.00, 0.045)
            // Medium cost states
            case "FL", "TX", "AZ", "NC", "GA", "TN":
                return (1800, 1.60, 0.05)
            case "MN", "WI", "UT", "SC":
                return (1600, 1.45, 0.05)
            // Lower cost states
            case "OH", "PA", "MI", "IL", "MO", "IN":
                return (1400, 1.25, 0.055)
            case "KY", "AL", "OK", "KS", "NE":
                return (1200, 1.10, 0.06)
            default:
                return (1500, 1.35, 0.05)
            }
        }()
        
        return RentMarketResult(
            medianRent: medianRent,
            rentGrowth: 0.035, // ~3.5% national average
            rentPerSqFt: rentPerSqFt,
            vacancyRate: vacancyRate
        )
    }
    
    // MARK: - Census Data (Free API)
    
    func fetchCensusData(zipCode: String) async throws -> CensusData {
        guard !APIConfiguration.Census.apiKey.isEmpty else {
            print("⚠️ [MarketDataService] No Census API key, using estimates")
            return CensusData.estimateData
        }
        
        // Census API for population and median household income by ZIP code
        // Using ACS 5-year estimates (most reliable)
        // B01003_001E = Total Population
        // B19013_001E = Median Household Income
        let apiKey = APIConfiguration.Census.apiKey
        let baseURL = APIConfiguration.Census.baseURL
        
        // URL encode the ZIP parameter properly
        let urlString = "\(baseURL)/2022/acs/acs5?get=B01003_001E,B19013_001E&for=zip%20code%20tabulation%20area:\(zipCode)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("⚠️ [MarketDataService] Invalid Census URL")
            return CensusData.estimateData
        }
        
        print("🏛️ [MarketDataService] Fetching Census data for ZIP: \(zipCode)")
        print("🏛️ [MarketDataService] Census URL: \(url.absoluteString)")
        
        do {
            let data = try await NetworkManager.shared.fetchData(url: url)
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("🏛️ [MarketDataService] Census response: \(responseString.prefix(200))...")
            }
            
            // Parse Census response (comes as array of arrays)
            // Format: [["B01003_001E","B19013_001E","zip code tabulation area"],["45000","72500","78701"]]
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else {
                print("⚠️ [MarketDataService] Could not parse Census JSON")
                return CensusData.estimateData
            }
            
            guard json.count > 1, let dataRow = json[1] as? [Any], dataRow.count >= 2 else {
                print("⚠️ [MarketDataService] Census response missing data rows")
                return CensusData.estimateData
            }
            
            // Values might come as String or Int/Double
            let population: Int? = {
                if let str = dataRow[0] as? String { return Int(str) }
                if let num = dataRow[0] as? Int { return num }
                if let num = dataRow[0] as? Double { return Int(num) }
                return nil
            }()
            
            let medianIncome: Double? = {
                if let str = dataRow[1] as? String { return Double(str) }
                if let num = dataRow[1] as? Double { return num }
                if let num = dataRow[1] as? Int { return Double(num) }
                return nil
            }()
            
            print("🏛️ [MarketDataService] Census data: pop=\(population ?? 0), income=$\(Int(medianIncome ?? 0))")
            
            return CensusData(
                population: population,
                medianIncome: medianIncome,
                populationGrowth: nil,
                incomeGrowth: nil
            )
        } catch {
            print("⚠️ [MarketDataService] Census API error: \(error.localizedDescription)")
            return CensusData.estimateData
        }
    }
}

extension CensusData {
    static var estimateData: CensusData {
        CensusData(
            population: nil,
            medianIncome: nil,
            populationGrowth: nil,
            incomeGrowth: nil
        )
    }
}

// MARK: - Result Types

struct RentMarketResult: Sendable {
    let medianRent: Double?
    let rentGrowth: Double?
    let rentPerSqFt: Double?
    let vacancyRate: Double?
}

struct HousingMarketResult: Sendable {
    let medianPrice: Double?
    let priceGrowth: Double?
    let pricePerSqFt: Double?
    let daysOnMarket: Int?
    let inventoryMonths: Double?
    
    static func estimateForState(_ state: String) -> HousingMarketResult {
        // Regional estimates
        let (price, pricePerSqft): (Double, Double) = {
            switch state.uppercased() {
            case "CA":
                return (750000, 550)
            case "NY":
                return (650000, 450)
            case "WA", "MA", "CO":
                return (550000, 380)
            case "FL", "TX", "AZ":
                return (400000, 250)
            case "NC", "GA", "TN", "SC":
                return (350000, 220)
            case "OH", "PA", "MI", "IL":
                return (280000, 180)
            default:
                return (350000, 200)
            }
        }()
        
        return HousingMarketResult(
            medianPrice: price,
            priceGrowth: 0.04, // ~4% average
            pricePerSqFt: pricePerSqft,
            daysOnMarket: 35,
            inventoryMonths: 3.0
        )
    }
}

struct CensusData: Sendable {
    let population: Int?
    let medianIncome: Double?
    let populationGrowth: Double?
    let incomeGrowth: Double?
}

// MARK: - Dock API Response Models (for market data)

struct DockMarketSearchResponse: Codable, Sendable {
    let count: Int
    let properties: [DockMarketListing]
}

struct DockMarketListing: Codable, Sendable {
    let price: Double?
    let pricePerSqft: Double?
    let daysOnMls: Int?
    
    enum CodingKeys: String, CodingKey {
        case price
        case pricePerSqft = "price_per_sqft"
        case daysOnMls = "days_on_mls"
    }
}
