//
//  APIConfiguration.swift
//  Dock
//
//  API configuration and key management
//

import Foundation

enum APIConfiguration {
    // MARK: - Keys
    
    private static var apiKeys: [String: Any]? {
        guard let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return dict
    }
    
    // MARK: - Dock Property API (HomeHarvest Backend)
    
    enum DockAPI {
        static var baseURL: String? {
            (apiKeys?["DockAPI"] as? [String: Any])?["BaseURL"] as? String
        }
    }
    
    // MARK: - FRED (Federal Reserve Economic Data) - Free API for interest rates
    
    enum FredAPI {
        static var apiKey: String {
            (apiKeys?["FredAPI"] as? [String: Any])?["APIKey"] as? String ?? ""
        }
        
        static var baseURL: String {
            (apiKeys?["FredAPI"] as? [String: Any])?["BaseURL"] as? String ?? "https://api.stlouisfed.org/fred"
        }
    }
    
    // MARK: - Census API - Free API for demographics (population, income)
    
    enum Census {
        static var apiKey: String {
            (apiKeys?["Census"] as? [String: Any])?["APIKey"] as? String ?? ""
        }
        
        static var baseURL: String {
            (apiKeys?["Census"] as? [String: Any])?["BaseURL"] as? String ?? "https://api.census.gov/data"
        }
    }
}

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case httpError(Int)
    case networkError(Error)
    case rateLimited
    case unauthorized
    case notFound
    case serverError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .unauthorized:
            return "Unauthorized. Check your API keys."
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error"
        case .unknown:
            return "Unknown error"
        }
    }
}
