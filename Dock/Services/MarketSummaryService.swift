//
//  MarketSummaryService.swift
//  Dock
//
//  Service for fetching city-level rent summaries from Dock API
//

import Foundation

actor MarketSummaryService {
    static let shared = MarketSummaryService()
    
    private init() {}
    
    func fetchCitySummary(city: String, state: String) async throws -> CityMarketSummaryResponse {
        guard let baseURL = APIConfiguration.DockAPI.baseURL,
              !baseURL.isEmpty else {
            throw NetworkError.invalidURL
        }
        
        var components = URLComponents(string: "\(baseURL)/market-summary")
        components?.queryItems = [
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "state", value: state)
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }
        
        let cacheKey = "market_summary_\(city.lowercased())_\(state.lowercased())"
        let response: CityMarketSummaryResponse = try await NetworkManager.shared.request(
            url: url,
            cacheKey: cacheKey
        )
        
        return response
    }
}
