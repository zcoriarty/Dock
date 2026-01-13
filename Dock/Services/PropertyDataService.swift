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
        
        let response: DockPropertyResponse = try await NetworkManager.shared.request(
            url: requestURL,
            cacheKey: "dock_property_\(url.hashValue)"
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
        
        let response: DockPropertyResponse = try await NetworkManager.shared.request(
            url: url,
            cacheKey: "dock_property_\(address.hashValue)"
        )
        
        print("✅ [PropertyDataService] Got response: \(response.address ?? "no address"), price: \(response.price ?? 0)")
        
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
    
    // MARK: - Mapping
    
    private func mapDockResponse(_ response: DockPropertyResponse) -> PropertyData {
        PropertyData(
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
            photoURLs: response.altPhotos ?? [],
            primaryPhotoURL: response.primaryPhoto,
            zestimate: response.estimatedValue,
            rentZestimate: nil, // Would need separate rent listing search
            description: response.description,
            daysOnMarket: response.daysOnMls,
            listingURL: response.listingUrl,
            mlsId: response.mlsId,
            hoaFee: response.hoaFee,
            pricePerSqft: response.pricePerSqft,
            soldPrice: response.soldPrice,
            lastSoldDate: response.lastSoldDate,
            listDate: response.listDate,
            source: response.source,
            agentName: response.agentName,
            brokerName: response.brokerName
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

enum ListingType: String, CaseIterable {
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
    let agentName: String?
    let brokerName: String?
    
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
        agentName: String? = nil,
        brokerName: String? = nil
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
        self.agentName = agentName
        self.brokerName = brokerName
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
            agentName: nil,
            brokerName: nil
        )
    }
}

// MARK: - Dock API Response Models

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
    
    enum CodingKeys: String, CodingKey {
        case address
        case city
        case state
        case zipCode = "zip_code"
        case latitude
        case longitude
        case price
        case bedrooms
        case bathrooms
        case sqft
        case lotSqft = "lot_sqft"
        case yearBuilt = "year_built"
        case propertyType = "property_type"
        case pricePerSqft = "price_per_sqft"
        case hoaFee = "hoa_fee"
        case daysOnMls = "days_on_mls"
        case listDate = "list_date"
        case soldPrice = "sold_price"
        case lastSoldDate = "last_sold_date"
        case assessedValue = "assessed_value"
        case estimatedValue = "estimated_value"
        case mlsId = "mls_id"
        case listingUrl = "listing_url"
        case primaryPhoto = "primary_photo"
        case altPhotos = "alt_photos"
        case source
        case status
        case description
        case agentName = "agent_name"
        case brokerName = "broker_name"
    }
}

struct DockSearchResponse: Codable, Sendable {
    let count: Int
    let properties: [DockPropertyResponse]
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
