//
//  PropertyDetailViewModel.swift
//  Dock
//
//  ViewModel for property detail and underwriting
//

import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
final class PropertyDetailViewModel {
    // MARK: - Properties
    
    var property: Property
    var isLoading: Bool = false
    var isFetchingData: Bool = false
    var errorMessage: String?
    var showingNotes: Bool = false
    var showingFinancing: Bool = false
    var showingSensitivity: Bool = false
    var activeSection: DetailSection = .summary
    
    // MARK: - Computed
    
    var metrics: DealMetrics {
        property.metrics
    }
    
    var canSave: Bool {
        !property.address.isEmpty && property.askingPrice > 0
    }
    
    // MARK: - Sections
    
    enum DetailSection: String, CaseIterable, Identifiable {
        case summary = "Summary"
        case economics = "Economics"
        case market = "Market"
        case risk = "Risk"
        case notes = "Notes"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .summary: return "chart.pie.fill"
            case .economics: return "dollarsign.circle.fill"
            case .market: return "chart.line.uptrend.xyaxis"
            case .risk: return "exclamationmark.shield.fill"
            case .notes: return "note.text"
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let propertyService = PropertyDataService.shared
    private let rentService = RentCompsService.shared
    private let marketService = MarketDataService.shared
    private let rateService = RateService.shared
    private let insuranceService = InsuranceService.shared
    
    private var onSave: ((Property) async -> Void)?
    
    // MARK: - Init
    
    init(property: Property, onSave: ((Property) async -> Void)? = nil) {
        self.property = property
        self.onSave = onSave
        
        // Set default financing if not set
        if property.financing.purchasePrice == 0 {
            self.property.financing.purchasePrice = property.askingPrice
            self.property.financing.updateLoanFromLTV()
        }
    }
    
    // MARK: - Data Fetching
    
    func fetchAllData() async {
        isFetchingData = true
        defer { isFetchingData = false }
        
        // First, refresh property data from API (including photos)
        await refreshPropertyData()
        
        // Then fetch additional data in parallel
        async let ratesTask: () = fetchRates()
        async let rentTask: () = fetchRentEstimate()
        async let marketTask: () = fetchMarketData()
        async let insuranceTask: () = fetchInsuranceEstimate()
        
        _ = await (ratesTask, rentTask, marketTask, insuranceTask)
        
        HapticManager.shared.success()
    }
    
    private func refreshPropertyData() async {
        let fullAddress = property.fullAddress
        guard !fullAddress.isEmpty else { return }
        
        // Check if we have a valid photo already
        let hasValidPhoto = property.primaryPhotoData != nil && 
                           UIImage(data: property.primaryPhotoData!) != nil
        
        // Skip if we already have a valid photo
        if hasValidPhoto {
            print("📸 Property already has a valid photo, skipping refresh")
            return
        }
        
        print("🔄 Refreshing property data for: \(fullAddress)")
        
        do {
            let propertyData = try await propertyService.fetchPropertyByAddress(fullAddress)
            
            // Update photo URLs and listing URL from fresh data
            var didUpdate = false
            if property.photoURLs != propertyData.photoURLs {
                property.photoURLs = propertyData.photoURLs
                didUpdate = true
            }
            if property.listingURL == nil, let listingURL = propertyData.listingURL {
                property.listingURL = listingURL
                didUpdate = true
            }
            
            // Download the photo
            let photoURLToTry = propertyData.primaryPhotoURL ?? propertyData.photoURLs.first
            if let photoURLString = photoURLToTry,
               let imageURL = URL(string: photoURLString) {
                print("📸 Downloading photo from: \(photoURLString)")
                let imageData = try await NetworkManager.shared.fetchData(url: imageURL)
                property.primaryPhotoData = imageData
                didUpdate = true
                print("📸 Photo downloaded successfully (\(imageData.count) bytes)")
            } else {
                print("⚠️ No photo URL available from API")
            }
            
            if didUpdate {
                property.updatedAt = Date()
                await onSave?(property)
            }
        } catch {
            print("⚠️ Could not refresh property data: \(error.localizedDescription)")
        }
    }
    
    func fetchFromListingURL(_ url: String) async {
        guard url.isPropertyListingURL else {
            errorMessage = "Please enter a valid property URL from Zillow, Redfin, or Realtor.com"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let propertyData = try await propertyService.fetchProperty(from: url)
            
            // Update property with fetched data
            property.listingURL = propertyData.listingURL ?? url
            property.address = propertyData.address
            property.city = propertyData.city
            property.state = propertyData.state
            property.zipCode = propertyData.zipCode
            property.latitude = propertyData.latitude
            property.longitude = propertyData.longitude
            property.askingPrice = propertyData.askingPrice
            property.bedrooms = propertyData.bedrooms
            property.bathrooms = propertyData.bathrooms
            property.squareFeet = propertyData.squareFeet
            property.lotSize = propertyData.lotSize
            property.yearBuilt = propertyData.yearBuilt
            property.propertyType = propertyData.propertyType
            property.taxAssessedValue = propertyData.taxAssessedValue
            property.annualTaxes = propertyData.annualTaxes
            property.photoURLs = propertyData.photoURLs
            
            // Download primary photo - try primary first, then fallback to first alt photo
            let photoURLToTry = propertyData.primaryPhotoURL ?? propertyData.photoURLs.first
            if let photoURLString = photoURLToTry,
               let imageURL = URL(string: photoURLString) {
                do {
                    let imageData = try await NetworkManager.shared.fetchData(url: imageURL)
                    property.primaryPhotoData = imageData
                } catch {
                    // Ignore photo download errors
                }
            }
            
            // Update financing
            property.financing.purchasePrice = propertyData.askingPrice
            property.financing.updateLoanFromLTV()
            
            // Use Zestimate rent if available
            if let rentZestimate = propertyData.rentZestimate {
                property.estimatedRentPerUnit = rentZestimate
                property.estimatedTotalRent = rentZestimate * Double(property.unitCount)
            }
            
            // Fetch additional data
            await fetchAllData()
            
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
    
    private func fetchRates() async {
        do {
            let rates = try await rateService.fetchCurrentRates()
            if let rate = rates.rate30YrFixed {
                property.financing.interestRate = rate
            }
        } catch {
            // Use fallback rates
            property.financing.interestRate = 0.07
        }
    }
    
    private func fetchRentEstimate() async {
        do {
            let estimate = try await rentService.fetchRentEstimate(
                address: property.address,
                city: property.city,
                state: property.state,
                zipCode: property.zipCode,
                bedrooms: property.bedrooms,
                bathrooms: property.bathrooms,
                squareFeet: property.squareFeet,
                propertyType: property.propertyType
            )
            
            if property.estimatedRentPerUnit == 0 {
                property.estimatedRentPerUnit = estimate.estimatedRent
                property.estimatedTotalRent = estimate.estimatedRent * Double(property.unitCount)
            }
        } catch {
            // Keep existing estimate or fallback
        }
    }
    
    private func fetchMarketData() async {
        do {
            let marketData = try await marketService.fetchMarketData(
                city: property.city,
                state: property.state,
                zipCode: property.zipCode
            )
            property.marketData = marketData
            
            // Update vacancy rate from market data
            if let vacancy = marketData.vacancyRate {
                property.vacancyRate = vacancy
            }
        } catch {
            // Use defaults
        }
    }
    
    private func fetchInsuranceEstimate() async {
        let estimate = await insuranceService.estimateInsurance(
            propertyValue: property.askingPrice,
            squareFeet: property.squareFeet,
            yearBuilt: property.yearBuilt,
            state: property.state,
            propertyType: property.propertyType
        )
        property.insuranceAnnual = estimate.totalAnnualCost
    }
    
    // MARK: - Save
    
    func save() async {
        property.updatedAt = Date()
        await onSave?(property)
        HapticManager.shared.success()
    }
    
    // MARK: - Updates
    
    func updatePurchasePrice(_ price: Double) {
        property.financing.purchasePrice = price
        property.financing.updateLoanFromLTV()
        HapticManager.shared.editField()
    }
    
    func updateLTV(_ ltv: Double) {
        property.financing.ltv = ltv
        property.financing.updateLoanFromLTV()
        HapticManager.shared.editField()
    }
    
    func updateInterestRate(_ rate: Double) {
        property.financing.interestRate = rate
        HapticManager.shared.editField()
    }
    
    func updateRent(_ rent: Double) {
        property.estimatedRentPerUnit = rent
        property.estimatedTotalRent = rent * Double(property.unitCount)
        HapticManager.shared.editField()
    }
    
    func updateVacancy(_ vacancy: Double) {
        property.vacancyRate = vacancy
        HapticManager.shared.editField()
    }
    
    func updateThreshold<T>(_ keyPath: WritableKeyPath<InvestmentThresholds, T>, value: T) {
        property.thresholds[keyPath: keyPath] = value
        HapticManager.shared.editField()
    }
}
