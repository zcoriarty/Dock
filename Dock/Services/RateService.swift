//
//  RateService.swift
//  Dock
//
//  Service for fetching current mortgage and interest rates
//

import Foundation

actor RateService {
    static let shared = RateService()
    
    private var cachedRates: RateData?
    private var lastFetch: Date?
    private let cacheTimeout: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    // MARK: - Fetch Current Rates
    
    func fetchCurrentRates() async throws -> RateData {
        // Check cache
        if let cached = cachedRates,
           let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheTimeout {
            return cached
        }
        
        // Try FRED API for rates
        async let rate30Yr = fetchFredSeries("MORTGAGE30US")
        async let rate15Yr = fetchFredSeries("MORTGAGE15US")
        async let treasury10Yr = fetchFredSeries("DGS10")
        async let primeRate = fetchFredSeries("DPRIME")
        
        let (r30, r15, t10, prime) = await (
            try? rate30Yr,
            try? rate15Yr,
            try? treasury10Yr,
            try? primeRate
        )
        
        let rates = RateData(
            fetchedAt: Date(),
            source: "FRED",
            rate30YrFixed: r30.map { $0 / 100 },
            rate15YrFixed: r15.map { $0 / 100 },
            rate5_1ARM: nil,
            rate7_1ARM: nil,
            primerate: prime.map { $0 / 100 },
            sofr: nil,
            treasuryRate10Yr: t10.map { $0 / 100 }
        )
        
        // Use fallback if no data
        if rates.rate30YrFixed == nil {
            return RateData.fallbackRates
        }
        
        cachedRates = rates
        lastFetch = Date()
        
        return rates
    }
    
    // MARK: - FRED API
    
    private func fetchFredSeries(_ seriesID: String) async throws -> Double? {
        guard !APIConfiguration.FredAPI.apiKey.isEmpty,
              APIConfiguration.FredAPI.apiKey != "YOUR_FRED_API_KEY" else {
            return nil
        }
        
        guard let url = URL(string: "\(APIConfiguration.FredAPI.baseURL)/series/observations?series_id=\(seriesID)&api_key=\(APIConfiguration.FredAPI.apiKey)&file_type=json&sort_order=desc&limit=1") else {
            throw NetworkError.invalidURL
        }
        
        let response: FredResponse = try await NetworkManager.shared.request(
            url: url,
            cacheKey: "fred_\(seriesID)"
        )
        
        guard let observation = response.observations?.first,
              let valueStr = observation.value,
              valueStr != ".",
              let value = Double(valueStr) else {
            return nil
        }
        
        return value
    }
    
    // MARK: - Calculate Monthly Payment
    
    nonisolated func calculateMonthlyPayment(
        principal: Double,
        annualRate: Double,
        termYears: Int,
        isInterestOnly: Bool = false
    ) -> Double {
        guard principal > 0, annualRate > 0, termYears > 0 else { return 0 }
        
        if isInterestOnly {
            return principal * (annualRate / 12)
        }
        
        let monthlyRate = annualRate / 12
        let numPayments = Double(termYears * 12)
        
        let payment = principal * (monthlyRate * pow(1 + monthlyRate, numPayments)) / (pow(1 + monthlyRate, numPayments) - 1)
        
        return payment
    }
}

// MARK: - FRED Response Models

struct FredResponse: Codable, Sendable {
    let observations: [FredObservation]?
}

struct FredObservation: Codable, Sendable {
    let date: String?
    let value: String?
}

// MARK: - Fallback Rates

extension RateData {
    static var fallbackRates: RateData {
        RateData(
            fetchedAt: Date(),
            source: "Fallback",
            rate30YrFixed: 0.0695,
            rate15YrFixed: 0.0625,
            rate5_1ARM: 0.0650,
            rate7_1ARM: 0.0675,
            primerate: 0.0850,
            sofr: 0.0530,
            treasuryRate10Yr: 0.0425
        )
    }
}
