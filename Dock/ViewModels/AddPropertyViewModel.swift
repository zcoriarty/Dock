//
//  AddPropertyViewModel.swift
//  Dock
//
//  ViewModel for adding new properties
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AddPropertyViewModel {
    // MARK: - Properties
    
    var searchAddress: String = ""
    var selectedAddressSuggestion: AddressSuggestion?
    var property: Property = Property()
    var isLoading: Bool = false
    var isFetchingData: Bool = false
    var errorMessage: String?
    var step: AddPropertyStep = .address
    var hasAttemptedFetch: Bool = false
    
    // MARK: - Steps
    
    enum AddPropertyStep: Int, CaseIterable {
        case address = 0
        case details = 1
        case financing = 2
        case review = 3
        
        var title: String {
            switch self {
            case .address: return "Address"
            case .details: return "Details"
            case .financing: return "Financing"
            case .review: return "Review"
            }
        }
        
        var icon: String {
            switch self {
            case .address: return "mappin.circle.fill"
            case .details: return "house.fill"
            case .financing: return "banknote.fill"
            case .review: return "checkmark.circle.fill"
            }
        }
    }
    
    // MARK: - Computed
    
    var canProceed: Bool {
        switch step {
        case .address:
            return !searchAddress.isEmpty || hasAttemptedFetch
        case .details:
            return !property.address.isEmpty && property.askingPrice > 0
        case .financing:
            return property.financing.purchasePrice > 0
        case .review:
            return true
        }
    }
    
    var hasValidAddress: Bool {
        !searchAddress.isEmpty && selectedAddressSuggestion != nil
    }
    
    // MARK: - Dependencies
    
    private let propertyService = PropertyDataService.shared
    private let rentService = RentCompsService.shared
    private let marketService = MarketDataService.shared
    private let rateService = RateService.shared
    private let insuranceService = InsuranceService.shared
    
    // MARK: - Address Completer
    
    let addressCompleter = AddressSearchCompleter()
    
    // MARK: - Actions
    
    /// Called when user selects an address from autocomplete
    func handleAddressSelection(_ suggestion: AddressSuggestion) {
        selectedAddressSuggestion = suggestion
        searchAddress = suggestion.fullAddress
        
        // Pre-populate basic address fields
        property.address = suggestion.title
        if !suggestion.subtitle.isEmpty {
            // Parse city, state from subtitle (e.g., "Austin, TX")
            let parts = suggestion.subtitle.components(separatedBy: ", ")
            if parts.count >= 1 {
                property.city = parts[0]
            }
            if parts.count >= 2 {
                // State might include ZIP
                let stateParts = parts[1].components(separatedBy: " ")
                property.state = stateParts[0]
                if stateParts.count > 1 {
                    property.zipCode = stateParts[1]
                }
            }
        }
    }
    
    /// Fetch property data from the selected address
    func fetchFromAddress() async {
        guard hasValidAddress, let suggestion = selectedAddressSuggestion else {
            errorMessage = "Please select an address from the suggestions"
            HapticManager.shared.warning()
            return
        }
        
        isLoading = true
        hasAttemptedFetch = true
        defer { isLoading = false }
        
        do {
            // First, get detailed address components from MapKit
            print("📍 Getting address details from MapKit...")
            let addressDetails = try await addressCompleter.getAddressDetails(for: suggestion)
            print("📍 Address details: \(addressDetails.fullAddress)")
            
            // Update property with address details
            property.address = addressDetails.streetAddress
            property.city = addressDetails.city
            property.state = addressDetails.state
            property.zipCode = addressDetails.zipCode
            property.latitude = addressDetails.latitude
            property.longitude = addressDetails.longitude
            
            // Try to fetch property data from API
            let fullAddress = addressDetails.fullAddress
            print("🏠 Fetching property data for: \(fullAddress)")
            
            do {
                let propertyData = try await propertyService.fetchPropertyByAddress(fullAddress)
                print("✅ Property data received: price=\(propertyData.askingPrice), beds=\(propertyData.bedrooms), baths=\(propertyData.bathrooms)")
                
                // Populate property from API response
                if property.askingPrice == 0 {
                    property.askingPrice = propertyData.askingPrice
                }
                if property.bedrooms == 0 {
                    property.bedrooms = propertyData.bedrooms
                }
                if property.bathrooms == 0 {
                    property.bathrooms = propertyData.bathrooms
                }
                if property.squareFeet == 0 {
                    property.squareFeet = propertyData.squareFeet
                }
                if property.lotSize == 0 {
                    property.lotSize = propertyData.lotSize
                }
                if property.yearBuilt == 0 {
                    property.yearBuilt = propertyData.yearBuilt
                }
                property.propertyType = propertyData.propertyType
                property.taxAssessedValue = propertyData.taxAssessedValue
                property.annualTaxes = propertyData.annualTaxes
                property.photoURLs = propertyData.photoURLs
                
                // Set financing
                if property.financing.purchasePrice == 0 {
                    property.financing.purchasePrice = propertyData.askingPrice
                    property.financing.updateLoanFromLTV()
                }
                
                // Use rent estimate if available
                if let rent = propertyData.rentZestimate {
                    property.estimatedRentPerUnit = rent
                    property.estimatedTotalRent = rent
                }
            } catch {
                // Property not found in listings - that's OK, user can enter manually
                print("⚠️ Property not found in listings: \(error.localizedDescription)")
            }
            
            // Fetch additional data (rates, rent estimates, market data)
            print("📊 Fetching additional data...")
            await fetchAdditionalData()
            print("📊 Additional data fetch complete")
            
            errorMessage = nil
            step = .details
            HapticManager.shared.success()
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
    
    func skipAddress() {
        hasAttemptedFetch = true
        step = .details
        HapticManager.shared.impact(.light)
    }
    
    func fetchAdditionalData() async {
        isFetchingData = true
        defer { isFetchingData = false }
        
        // Fetch rates
        do {
            print("💰 Fetching interest rates...")
            let rates = try await rateService.fetchCurrentRates()
            if let rate = rates.rate30YrFixed {
                property.financing.interestRate = rate
                print("💰 Got rate: \(rate * 100)%")
            }
        } catch {
            print("⚠️ Rate fetch failed: \(error.localizedDescription), using default 7%")
            property.financing.interestRate = 0.07
        }
        
        // Estimate rent if not set
        if property.estimatedRentPerUnit == 0 && property.bedrooms > 0 {
            print("🏠 Estimating rent...")
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
                property.estimatedRentPerUnit = estimate.estimatedRent
                property.estimatedTotalRent = estimate.estimatedRent * Double(property.unitCount)
                print("🏠 Rent estimate: $\(Int(estimate.estimatedRent))/mo (source: \(estimate.source))")
            } catch {
                print("⚠️ Rent estimate failed: \(error.localizedDescription)")
            }
        }
        
        // Fetch market data from Dock API
        if !property.city.isEmpty && !property.state.isEmpty {
            print("📈 Fetching market data for \(property.city), \(property.state)...")
            do {
                let marketData = try await marketService.fetchMarketData(
                    city: property.city,
                    state: property.state,
                    zipCode: property.zipCode
                )
                property.marketData = marketData
                if let vacancy = marketData.vacancyRate {
                    property.vacancyRate = vacancy
                }
                if let medianPrice = marketData.medianHomePrice {
                    print("📈 Market data: median price $\(Int(medianPrice)), vacancy \((marketData.vacancyRate ?? 0) * 100)%")
                }
            } catch {
                print("⚠️ Market data failed: \(error.localizedDescription)")
            }
        }
        
        // Fetch insurance estimate
        if property.askingPrice > 0 {
            print("🛡️ Estimating insurance...")
            let insurance = await insuranceService.estimateInsurance(
                propertyValue: property.askingPrice,
                squareFeet: property.squareFeet,
                yearBuilt: property.yearBuilt,
                state: property.state,
                propertyType: property.propertyType
            )
            property.insuranceAnnual = insurance.totalAnnualCost
            print("🛡️ Insurance estimate: $\(insurance.totalAnnualCost)/yr")
        }
    }
    
    func nextStep() {
        guard canProceed else { return }
        
        if step.rawValue < AddPropertyStep.allCases.count - 1 {
            step = AddPropertyStep(rawValue: step.rawValue + 1) ?? step
            HapticManager.shared.impact(.light)
        }
    }
    
    func previousStep() {
        if step.rawValue > 0 {
            step = AddPropertyStep(rawValue: step.rawValue - 1) ?? step
            HapticManager.shared.impact(.light)
        }
    }
    
    func reset() {
        searchAddress = ""
        selectedAddressSuggestion = nil
        property = Property()
        step = .address
        hasAttemptedFetch = false
        errorMessage = nil
        addressCompleter.clearSuggestions()
    }
}
