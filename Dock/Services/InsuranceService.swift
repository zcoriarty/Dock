//
//  InsuranceService.swift
//  Dock
//
//  Service for estimating property insurance costs
//

import Foundation

actor InsuranceService {
    static let shared = InsuranceService()
    
    private init() {}
    
    // MARK: - Estimate Insurance
    
    func estimateInsurance(
        propertyValue: Double,
        squareFeet: Int,
        yearBuilt: Int,
        state: String,
        propertyType: PropertyType
    ) -> InsuranceEstimate {
        // Base rate per $1000 of coverage
        let baseRate = getBaseRate(state: state)
        
        // Adjustments
        let ageAdjustment = getAgeAdjustment(yearBuilt: yearBuilt)
        let typeAdjustment = getTypeAdjustment(propertyType: propertyType)
        let sizeAdjustment = getSizeAdjustment(squareFeet: squareFeet)
        
        // Calculate premium
        let coverage = propertyValue * 0.80 // Typically 80% of value
        let adjustedRate = baseRate * ageAdjustment * typeAdjustment * sizeAdjustment
        let annualPremium = (coverage / 1000) * adjustedRate
        
        // Check flood zone (simplified - would use FEMA API in production)
        let isFloodZone = isHighRiskFloodArea(state: state)
        let floodInsurance = isFloodZone ? estimateFloodInsurance(coverage: coverage) : nil
        
        return InsuranceEstimate(
            fetchedAt: Date(),
            source: "Estimate",
            annualPremium: annualPremium,
            coverage: coverage,
            deductible: max(1000, coverage * 0.01),
            isFloodZone: isFloodZone,
            floodInsurance: floodInsurance
        )
    }
    
    // MARK: - Base Rates by State
    
    private func getBaseRate(state: String) -> Double {
        // Average annual premium per $1000 of coverage by state
        let rates: [String: Double] = [
            "AL": 6.5, "AK": 5.0, "AZ": 4.5, "AR": 6.0, "CA": 4.8,
            "CO": 5.5, "CT": 5.2, "DE": 4.8, "FL": 9.5, "GA": 5.8,
            "HI": 3.5, "ID": 4.0, "IL": 5.0, "IN": 4.8, "IA": 5.5,
            "KS": 7.0, "KY": 5.2, "LA": 8.5, "ME": 4.2, "MD": 4.5,
            "MA": 4.8, "MI": 5.0, "MN": 5.2, "MS": 7.5, "MO": 6.0,
            "MT": 4.5, "NE": 6.5, "NV": 4.0, "NH": 4.5, "NJ": 5.0,
            "NM": 4.8, "NY": 5.5, "NC": 5.5, "ND": 5.8, "OH": 4.5,
            "OK": 8.0, "OR": 3.8, "PA": 4.5, "RI": 5.5, "SC": 6.0,
            "SD": 5.5, "TN": 5.5, "TX": 7.5, "UT": 4.0, "VT": 4.5,
            "VA": 4.5, "WA": 4.0, "WV": 4.8, "WI": 4.5, "WY": 4.5
        ]
        
        return rates[state.uppercased()] ?? 5.0
    }
    
    // MARK: - Adjustments
    
    private func getAgeAdjustment(yearBuilt: Int) -> Double {
        let age = Calendar.current.component(.year, from: Date()) - yearBuilt
        
        switch age {
        case 0...10: return 0.85
        case 11...20: return 0.95
        case 21...30: return 1.0
        case 31...50: return 1.15
        default: return 1.30
        }
    }
    
    private func getTypeAdjustment(propertyType: PropertyType) -> Double {
        switch propertyType {
        case .singleFamily: return 1.0
        case .condo: return 0.85
        case .townhouse: return 0.95
        case .multiFamily, .duplex, .triplex, .fourplex: return 1.15
        case .apartment: return 1.20
        case .mobile: return 1.50
        case .commercial: return 1.40
        case .land: return 0.10
        case .other: return 1.0
        }
    }
    
    private func getSizeAdjustment(squareFeet: Int) -> Double {
        switch squareFeet {
        case 0...1500: return 0.90
        case 1501...2500: return 1.0
        case 2501...4000: return 1.10
        default: return 1.20
        }
    }
    
    // MARK: - Flood Risk
    
    private func isHighRiskFloodArea(state: String) -> Bool {
        // Simplified - states with higher flood risk
        let highRiskStates = ["FL", "LA", "TX", "NC", "SC", "MS", "AL"]
        return highRiskStates.contains(state.uppercased())
    }
    
    private func estimateFloodInsurance(coverage: Double) -> Double {
        // NFIP average rates
        let baseRate = 3.5 // per $1000
        return (coverage / 1000) * baseRate
    }
}
