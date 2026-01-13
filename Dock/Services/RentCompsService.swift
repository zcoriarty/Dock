//
//  RentCompsService.swift
//  Dock
//
//  Service for estimating rent using local calculations
//

import Foundation

actor RentCompsService {
    static let shared = RentCompsService()
    
    private init() {}
    
    // MARK: - Fetch Rent Estimate (Local Calculation)
    
    func fetchRentEstimate(
        address: String,
        city: String,
        state: String,
        zipCode: String,
        bedrooms: Int,
        bathrooms: Double,
        squareFeet: Int,
        propertyType: PropertyType
    ) async throws -> RentEstimate {
        // Use local estimation based on regional averages
        return estimateRent(
            squareFeet: squareFeet,
            bedrooms: bedrooms,
            bathrooms: bathrooms,
            state: state,
            propertyType: propertyType
        )
    }
    
    // MARK: - Local Rent Estimation
    
    private func estimateRent(
        squareFeet: Int,
        bedrooms: Int,
        bathrooms: Double,
        state: String,
        propertyType: PropertyType
    ) -> RentEstimate {
        // Regional rent-per-sqft based on state (2024 averages)
        let baseRentPerSqFt: Double = {
            switch state.uppercased() {
            // High cost states
            case "CA":
                return 2.80
            case "NY":
                return 2.60
            case "MA", "WA", "NJ", "CT":
                return 2.30
            case "CO", "OR", "MD", "VA", "DC":
                return 2.00
            // Medium cost states
            case "FL", "TX", "AZ", "NC", "GA", "TN", "NV":
                return 1.60
            case "MN", "WI", "UT", "SC", "NH":
                return 1.45
            // Lower cost states
            case "OH", "PA", "MI", "IL", "MO", "IN":
                return 1.25
            case "KY", "AL", "OK", "KS", "NE", "IA":
                return 1.10
            case "WV", "AR", "MS", "LA":
                return 1.00
            default:
                return 1.35
            }
        }()
        
        // Property type multiplier
        let propertyMultiplier: Double = {
            switch propertyType {
            case .singleFamily:
                return 1.1  // Premium for single family
            case .townhouse:
                return 1.05
            case .condo:
                return 1.0
            case .duplex, .triplex, .multiFamily:
                return 0.95  // Slight discount per unit
            case .apartment:
                return 0.90
            default:
                return 1.0
            }
        }()
        
        // Calculate base rent
        var estimatedRent = Double(squareFeet) * baseRentPerSqFt * propertyMultiplier
        
        // Bedroom adjustment (premium for more bedrooms)
        let bedroomPremium: Double = {
            switch bedrooms {
            case 1: return 0
            case 2: return 100
            case 3: return 175
            case 4: return 250
            case 5: return 325
            default: return 350 + Double(bedrooms - 5) * 50
            }
        }()
        estimatedRent += bedroomPremium
        
        // Bathroom adjustment
        let bathroomPremium = (bathrooms - 1.0) * 75
        estimatedRent += max(0, bathroomPremium)
        
        // Ensure minimum rent
        estimatedRent = max(estimatedRent, 800)
        
        // Round to nearest $25
        estimatedRent = (estimatedRent / 25).rounded() * 25
        
        return RentEstimate(
            estimatedRent: estimatedRent,
            rentLow: estimatedRent * 0.85,
            rentHigh: estimatedRent * 1.15,
            rentPerSquareFoot: Double(squareFeet) > 0 ? estimatedRent / Double(squareFeet) : baseRentPerSqFt,
            confidence: 0.7,
            source: "Local Estimate",
            fetchedAt: Date()
        )
    }
    
    // MARK: - Fetch Rent Comps (Mock/Placeholder)
    
    func fetchRentComps(
        latitude: Double,
        longitude: Double,
        bedrooms: Int,
        radius: Double = 1.0
    ) async throws -> [RentComp] {
        // Return empty - comps would require API access
        return []
    }
}

// MARK: - Rent Estimate Result

struct RentEstimate: Sendable {
    let estimatedRent: Double
    let rentLow: Double
    let rentHigh: Double
    let rentPerSquareFoot: Double
    let confidence: Double
    let source: String
    let fetchedAt: Date
}
