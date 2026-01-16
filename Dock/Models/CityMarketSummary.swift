//
//  CityMarketSummary.swift
//  Dock
//
//  Market summary metrics for tracked cities
//

import Foundation

struct CityMarketSummary: Identifiable, Hashable, Sendable {
    let city: String
    let state: String
    let averageRent: Double?
    let medianRent: Double?
    let newListingsLastWeek: Int?
    let sampleSize: Int?
    let source: String?
    let fetchedAt: Date
    let propertyCount: Int
    
    var id: String {
        "\(city.lowercased())-\(state.lowercased())"
    }
}

struct CityMarketSummaryResponse: Decodable, Hashable, Sendable {
    let city: String
    let state: String
    let averageRent: Double?
    let medianRent: Double?
    let newListingsLastWeek: Int?
    let sampleSize: Int?
    let source: String?
}
