//
//  PropertyDataService.swift
//  Dock
//
//  Service for fetching property data from Dock Property API (HomeHarvest backend)
//

import Foundation

actor PropertyDataService {
    static let shared = PropertyDataService()
    
    private init() {}
    
    // MARK: - Fetch Property from URL
    
    func fetchProperty(from listingURL: String) async throws -> PropertyData {
        // Check if it's a valid listing URL
        let isValidURL = listingURL.lowercased().contains("zillow.com") ||
                        listingURL.lowercased().contains("redfin.com") ||
                        listingURL.lowercased().contains("realtor.com")
        
        if isValidURL {
            return try await fetchPropertyByURL(listingURL)
        } else {
            // Treat as address
            return try await fetchPropertyByAddress(listingURL)
        }
    }
    
    // MARK: - Fetch by Listing URL
    
    func fetchPropertyByURL(_ url: String) async throws -> PropertyData {
        guard let baseURL = APIConfiguration.DockAPI.baseURL,
              !baseURL.isEmpty else {
            // Return mock data if no API configured
            return PropertyData.mockData
        }
        
        guard let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let requestURL = URL(string: "\(baseURL)/property/url?url=\(encodedURL)") else {
            throw NetworkError.invalidURL
        }
        
        // Don't cache property requests - we want fresh data with photos
        let response: DockPropertyResponse = try await NetworkManager.shared.request(
            url: requestURL
        )
        
        return mapDockResponse(response)
    }
    
    // MARK: - Fetch by Address
    
    func fetchPropertyByAddress(_ address: String) async throws -> PropertyData {
        guard let baseURL = APIConfiguration.DockAPI.baseURL,
              !baseURL.isEmpty else {
            print("🔴 [PropertyDataService] No API URL configured, returning mock data")
            return PropertyData.mockData
        }
        
        print("🌐 [PropertyDataService] Base URL: \(baseURL)")
        
        guard let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/property?address=\(encodedAddress)") else {
            print("🔴 [PropertyDataService] Failed to create URL for address: \(address)")
            throw NetworkError.invalidURL
        }
        
        print("🌐 [PropertyDataService] Requesting: \(url.absoluteString)")
        
        // Don't cache property requests - we want fresh data with photos
        let response: DockPropertyResponse = try await NetworkManager.shared.request(
            url: url
        )
        
        // Log full response details for debugging
        print("✅ [PropertyDataService] Got response:")
        print("   address: \(response.address ?? "nil")")
        print("   city: \(response.city ?? "nil"), state: \(response.state ?? "nil"), zip: \(response.zipCode ?? "nil")")
        print("   price: \(response.price ?? 0)")
        print("   beds: \(response.bedrooms ?? 0), baths: \(response.bathrooms ?? 0), sqft: \(response.sqft ?? 0)")
        print("   yearBuilt: \(response.yearBuilt ?? 0)")
        print("   primaryPhoto: \(response.primaryPhoto ?? "nil")")
        print("   listingUrl: \(response.listingUrl ?? "nil")")
        
        return mapDockResponse(response)
    }
    
    // MARK: - Search Properties
    
    func searchProperties(
        location: String,
        listingType: ListingType = .forSale,
        minPrice: Int? = nil,
        maxPrice: Int? = nil,
        minBeds: Int? = nil,
        maxBeds: Int? = nil,
        minBaths: Int? = nil,
        minSqft: Int? = nil,
        maxSqft: Int? = nil,
        limit: Int = 50
    ) async throws -> [PropertyData] {
        guard let baseURL = APIConfiguration.DockAPI.baseURL,
              !baseURL.isEmpty else {
            return [PropertyData.mockData]
        }
        
        var components = URLComponents(string: "\(baseURL)/search")
        var queryItems = [URLQueryItem]()
        
        queryItems.append(URLQueryItem(name: "location", value: location))
        queryItems.append(URLQueryItem(name: "listing_type", value: listingType.rawValue))
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        
        if let minPrice = minPrice {
            queryItems.append(URLQueryItem(name: "min_price", value: String(minPrice)))
        }
        if let maxPrice = maxPrice {
            queryItems.append(URLQueryItem(name: "max_price", value: String(maxPrice)))
        }
        if let minBeds = minBeds {
            queryItems.append(URLQueryItem(name: "min_beds", value: String(minBeds)))
        }
        if let maxBeds = maxBeds {
            queryItems.append(URLQueryItem(name: "max_beds", value: String(maxBeds)))
        }
        if let minBaths = minBaths {
            queryItems.append(URLQueryItem(name: "min_baths", value: String(minBaths)))
        }
        if let minSqft = minSqft {
            queryItems.append(URLQueryItem(name: "min_sqft", value: String(minSqft)))
        }
        if let maxSqft = maxSqft {
            queryItems.append(URLQueryItem(name: "max_sqft", value: String(maxSqft)))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }
        
        let response: DockSearchResponse = try await NetworkManager.shared.request(url: url)
        
        return response.properties.map { mapDockResponse($0) }
    }

    // MARK: - Investment Search

    func searchInvestmentProperties(criteria: InvestmentSearchCriteria) async throws -> [InvestmentSearchResult] {
        guard let baseURL = APIConfiguration.DockAPI.baseURL,
              !baseURL.isEmpty else {
            return []
        }

        guard let url = URL(string: "\(baseURL)/investment-search") else {
            throw NetworkError.invalidURL
        }

        let requestPayload = DockInvestmentSearchRequest(criteria: criteria)
        let response: DockInvestmentSearchResponse = try await NetworkManager.shared.post(
            url: url,
            body: requestPayload
        )

        return response.results.map { result in
            InvestmentSearchResult(
                id: result.id,
                property: mapDockResponse(result.property),
                metrics: InvestmentSearchMetrics(
                    estimatedRent: result.metrics.estimatedRent,
                    effectiveGrossIncome: result.metrics.effectiveGrossIncome,
                    netOperatingIncome: result.metrics.netOperatingIncome,
                    capRate: result.metrics.capRate,
                    cashOnCash: result.metrics.cashOnCash,
                    dscr: result.metrics.dscr,
                    annualCashFlow: result.metrics.annualCashFlow,
                    annualDebtService: result.metrics.annualDebtService,
                    totalCashRequired: result.metrics.totalCashRequired,
                    score: result.metrics.score
                )
            )
        }
    }
    
    // MARK: - Mapping
    
    private func mapDockResponse(_ response: DockPropertyResponse) -> PropertyData {
        // Clean up photo URLs - filter out empty strings
        let primaryPhoto = response.primaryPhoto?.nilIfEmpty
        let altPhotos = response.altPhotos?.compactMap { $0.nilIfEmpty } ?? []
        let listingUrl = response.listingUrl?.nilIfEmpty
        
        // Build combined photoURLs array with primary first (if available)
        // This ensures the primary photo URL is available for AsyncImage fallback
        var combinedPhotoURLs: [String] = []
        if let primary = primaryPhoto {
            combinedPhotoURLs.append(primary)
        }
        // Add alt photos, avoiding duplicates
        for altPhoto in altPhotos {
            if !combinedPhotoURLs.contains(altPhoto) {
                combinedPhotoURLs.append(altPhoto)
            }
        }
        
        // Debug logging for photo data
        print("📷 [PropertyDataService] API Response photos:")
        print("   primaryPhoto: \(primaryPhoto ?? "nil")")
        print("   altPhotos count: \(altPhotos.count)")
        print("   combinedPhotoURLs count: \(combinedPhotoURLs.count)")
        if let firstURL = combinedPhotoURLs.first {
            print("   first photoURL: \(firstURL)")
        }
        print("   listingUrl: \(listingUrl ?? "nil")")
        
        return PropertyData(
            address: response.address ?? "",
            city: response.city ?? "",
            state: response.state ?? "",
            zipCode: response.zipCode ?? "",
            latitude: response.latitude,
            longitude: response.longitude,
            askingPrice: response.price ?? 0,
            bedrooms: response.bedrooms ?? 0,
            bathrooms: response.bathrooms ?? 0,
            squareFeet: response.sqft ?? 0,
            lotSize: response.lotSqft ?? 0,
            yearBuilt: response.yearBuilt ?? 0,
            propertyType: mapPropertyType(response.propertyType),
            taxAssessedValue: response.assessedValue ?? 0,
            annualTaxes: 0, // Not provided by HomeHarvest
            photoURLs: combinedPhotoURLs, // Now includes primary photo first for fallback
            primaryPhotoURL: primaryPhoto,
            zestimate: response.estimatedValue,
            rentZestimate: nil, // Would need separate rent listing search
            description: response.description,
            daysOnMarket: response.daysOnMls,
            listingURL: listingUrl,
            mlsId: response.mlsId,
            hoaFee: response.hoaFee,
            pricePerSqft: response.pricePerSqft,
            soldPrice: response.soldPrice,
            lastSoldDate: response.lastSoldDate,
            listDate: response.listDate,
            source: response.source,
            status: response.status,
            agentName: response.agentName,
            brokerName: response.brokerName,
            stories: response.stories,
            parkingGarage: response.parkingGarage
        )
    }
    
    private func mapPropertyType(_ type: String?) -> PropertyType {
        guard let type = type?.lowercased() else { return .singleFamily }
        
        switch type {
        case let t where t.contains("single"):
            return .singleFamily
        case let t where t.contains("multi"):
            return .multiFamily
        case let t where t.contains("condo"):
            return .condo
        case let t where t.contains("town"):
            return .townhouse
        case let t where t.contains("duplex"):
            return .duplex
        case let t where t.contains("triplex"):
            return .triplex
        case let t where t.contains("apartment"):
            return .apartment
        case let t where t.contains("land"):
            return .land
        case let t where t.contains("mobile"):
            return .mobile
        default:
            return .singleFamily
        }
    }
}

// MARK: - Listing Type

enum ListingType: String, CaseIterable, Codable {
    case forSale = "for_sale"
    case forRent = "for_rent"
    case sold = "sold"
    case pending = "pending"
    
    var displayName: String {
        switch self {
        case .forSale: return "For Sale"
        case .forRent: return "For Rent"
        case .sold: return "Sold"
        case .pending: return "Pending"
        }
    }
}

// MARK: - Property Data Result

struct PropertyData: Sendable {
    let address: String
    let city: String
    let state: String
    let zipCode: String
    let latitude: Double?
    let longitude: Double?
    let askingPrice: Double
    let bedrooms: Int
    let bathrooms: Double
    let squareFeet: Int
    let lotSize: Int
    let yearBuilt: Int
    let propertyType: PropertyType
    let taxAssessedValue: Double
    let annualTaxes: Double
    let photoURLs: [String]
    let primaryPhotoURL: String?
    let zestimate: Double?
    let rentZestimate: Double?
    let description: String?
    let daysOnMarket: Int?
    let listingURL: String?
    let mlsId: String?
    let hoaFee: Double?
    let pricePerSqft: Double?
    let soldPrice: Double?
    let lastSoldDate: String?
    let listDate: String?
    let source: String?
    let status: String?
    let agentName: String?
    let brokerName: String?
    let stories: Int?
    let parkingGarage: Int?
    
    // Legacy initializer for backward compatibility
    init(
        address: String,
        city: String,
        state: String,
        zipCode: String,
        latitude: Double?,
        longitude: Double?,
        askingPrice: Double,
        bedrooms: Int,
        bathrooms: Double,
        squareFeet: Int,
        lotSize: Int,
        yearBuilt: Int,
        propertyType: PropertyType,
        taxAssessedValue: Double,
        annualTaxes: Double,
        photoURLs: [String],
        primaryPhotoURL: String?,
        zestimate: Double?,
        rentZestimate: Double?,
        description: String?,
        daysOnMarket: Int? = nil,
        listingURL: String? = nil,
        mlsId: String? = nil,
        hoaFee: Double? = nil,
        pricePerSqft: Double? = nil,
        soldPrice: Double? = nil,
        lastSoldDate: String? = nil,
        listDate: String? = nil,
        source: String? = nil,
        status: String? = nil,
        agentName: String? = nil,
        brokerName: String? = nil,
        stories: Int? = nil,
        parkingGarage: Int? = nil
    ) {
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
        self.taxAssessedValue = taxAssessedValue
        self.annualTaxes = annualTaxes
        self.photoURLs = photoURLs
        self.primaryPhotoURL = primaryPhotoURL
        self.zestimate = zestimate
        self.rentZestimate = rentZestimate
        self.description = description
        self.daysOnMarket = daysOnMarket
        self.listingURL = listingURL
        self.mlsId = mlsId
        self.hoaFee = hoaFee
        self.pricePerSqft = pricePerSqft
        self.soldPrice = soldPrice
        self.lastSoldDate = lastSoldDate
        self.listDate = listDate
        self.source = source
        self.status = status
        self.agentName = agentName
        self.brokerName = brokerName
        self.stories = stories
        self.parkingGarage = parkingGarage
    }
    
    static var mockData: PropertyData {
        PropertyData(
            address: "123 Main St",
            city: "Austin",
            state: "TX",
            zipCode: "78701",
            latitude: 30.2672,
            longitude: -97.7431,
            askingPrice: 450000,
            bedrooms: 3,
            bathrooms: 2,
            squareFeet: 1800,
            lotSize: 6500,
            yearBuilt: 1985,
            propertyType: .singleFamily,
            taxAssessedValue: 380000,
            annualTaxes: 8500,
            photoURLs: [],
            primaryPhotoURL: nil,
            zestimate: 465000,
            rentZestimate: 2400,
            description: "Charming single family home in great location",
            daysOnMarket: 14,
            listingURL: nil,
            mlsId: nil,
            hoaFee: nil,
            pricePerSqft: 250,
            soldPrice: nil,
            lastSoldDate: nil,
            listDate: nil,
            source: "mock",
            status: "for_sale",
            agentName: nil,
            brokerName: nil,
            stories: 2,
            parkingGarage: 2
        )
    }
}

// MARK: - Dock API Response Models

/// Response model from Dock API
/// Note: NetworkManager uses .convertFromSnakeCase, so no CodingKeys needed
struct DockPropertyResponse: Codable, Sendable {
    let address: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let latitude: Double?
    let longitude: Double?
    let price: Double?
    let bedrooms: Int?
    let bathrooms: Double?
    let sqft: Int?
    let lotSqft: Int?
    let yearBuilt: Int?
    let propertyType: String?
    let pricePerSqft: Double?
    let hoaFee: Double?
    let daysOnMls: Int?
    let listDate: String?
    let soldPrice: Double?
    let lastSoldDate: String?
    let assessedValue: Double?
    let estimatedValue: Double?
    let mlsId: String?
    let listingUrl: String?
    let primaryPhoto: String?
    let altPhotos: [String]?
    let source: String?
    let status: String?
    let description: String?
    let agentName: String?
    let brokerName: String?
    let stories: Int?
    let parkingGarage: Int?
}

struct DockSearchResponse: Codable, Sendable {
    let count: Int
    let properties: [DockPropertyResponse]
}

// MARK: - Investment Search API Models

struct DockInvestmentSearchRequest: Encodable {
    let location: String
    let listingType: String
    let minPrice: Int?
    let maxPrice: Int?
    let minBeds: Int?
    let maxBeds: Int?
    let minBaths: Int?
    let minSqft: Int?
    let maxSqft: Int?
    let minLotSqft: Int?
    let maxLotSqft: Int?
    let minYearBuilt: Int?
    let maxYearBuilt: Int?
    let maxDaysOnMarket: Int?
    let minCapRate: Double?
    let minCashOnCash: Double?
    let minDscr: Double?
    let targetCapRate: Double
    let targetCashOnCash: Double
    let targetDscr: Double
    let interestRate: Double
    let downPaymentPercent: Double
    let closingCostPercent: Double
    let vacancyRate: Double
    let managementFeePercent: Double
    let repairsPerYear: Double
    let insuranceRate: Double
    let otherExpensesAnnual: Double
    let rentSensitivity: Double
    let limit: Int
    let pastDays: Int?

    init(criteria: InvestmentSearchCriteria) {
        location = criteria.location
        listingType = criteria.listingType.rawValue
        minPrice = criteria.minPrice > 0 ? Int(criteria.minPrice) : nil
        maxPrice = criteria.maxPrice > 0 ? Int(criteria.maxPrice) : nil
        minBeds = criteria.minBeds > 0 ? criteria.minBeds : nil
        maxBeds = criteria.maxBeds > 0 ? criteria.maxBeds : nil
        minBaths = criteria.minBaths > 0 ? criteria.minBaths : nil
        minSqft = criteria.minSqft > 0 ? criteria.minSqft : nil
        maxSqft = criteria.maxSqft > 0 ? criteria.maxSqft : nil
        minLotSqft = criteria.minLotSqft > 0 ? criteria.minLotSqft : nil
        maxLotSqft = criteria.maxLotSqft > 0 ? criteria.maxLotSqft : nil
        minYearBuilt = criteria.minYearBuilt > 0 ? criteria.minYearBuilt : nil
        maxYearBuilt = criteria.maxYearBuilt > 0 ? criteria.maxYearBuilt : nil
        maxDaysOnMarket = criteria.maxDaysOnMarket > 0 ? criteria.maxDaysOnMarket : nil
        minCapRate = criteria.minCapRate > 0 ? criteria.minCapRate : nil
        minCashOnCash = criteria.minCashOnCash > 0 ? criteria.minCashOnCash : nil
        minDscr = criteria.minDSCR > 0 ? criteria.minDSCR : nil
        targetCapRate = criteria.targetCapRate
        targetCashOnCash = criteria.targetCashOnCash
        targetDscr = criteria.targetDSCR
        interestRate = criteria.interestRate
        downPaymentPercent = criteria.downPaymentPercent
        closingCostPercent = criteria.closingCostPercent
        vacancyRate = criteria.vacancyRate
        managementFeePercent = criteria.managementFeePercent
        repairsPerYear = criteria.repairsPerYear
        insuranceRate = criteria.insuranceRate
        otherExpensesAnnual = criteria.otherExpensesAnnual
        rentSensitivity = criteria.rentSensitivity
        limit = criteria.limit
        pastDays = criteria.pastDays > 0 ? criteria.pastDays : nil
    }

    enum CodingKeys: String, CodingKey {
        case location
        case listingType = "listing_type"
        case minPrice = "min_price"
        case maxPrice = "max_price"
        case minBeds = "min_beds"
        case maxBeds = "max_beds"
        case minBaths = "min_baths"
        case minSqft = "min_sqft"
        case maxSqft = "max_sqft"
        case minLotSqft = "min_lot_sqft"
        case maxLotSqft = "max_lot_sqft"
        case minYearBuilt = "min_year_built"
        case maxYearBuilt = "max_year_built"
        case maxDaysOnMarket = "max_days_on_market"
        case minCapRate = "min_cap_rate"
        case minCashOnCash = "min_cash_on_cash"
        case minDscr = "min_dscr"
        case targetCapRate = "target_cap_rate"
        case targetCashOnCash = "target_cash_on_cash"
        case targetDscr = "target_dscr"
        case interestRate = "interest_rate"
        case downPaymentPercent = "down_payment_percent"
        case closingCostPercent = "closing_cost_percent"
        case vacancyRate = "vacancy_rate"
        case managementFeePercent = "management_fee_percent"
        case repairsPerYear = "repairs_per_year"
        case insuranceRate = "insurance_rate"
        case otherExpensesAnnual = "other_expenses_annual"
        case rentSensitivity = "rent_sensitivity"
        case limit
        case pastDays = "past_days"
    }
}

struct DockInvestmentSearchResponse: Codable, Sendable {
    let count: Int
    let results: [DockInvestmentResultResponse]
    let sortedBy: String?
}

struct DockInvestmentResultResponse: Codable, Sendable {
    let id: String
    let property: DockPropertyResponse
    let metrics: DockInvestmentMetricsResponse
}

struct DockInvestmentMetricsResponse: Codable, Sendable {
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

// MARK: - Errors

enum PropertyDataError: LocalizedError {
    case invalidURL
    case propertyNotFound
    case parsingError
    case apiNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL or address"
        case .propertyNotFound:
            return "Property not found"
        case .parsingError:
            return "Failed to parse property data"
        case .apiNotConfigured:
            return "Dock API is not configured. Please set the API URL."
        }
    }
}
