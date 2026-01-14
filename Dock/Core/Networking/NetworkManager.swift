//
//  NetworkManager.swift
//  Dock
//
//  Centralized network manager with Swift concurrency
//

import Foundation

actor NetworkManager {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private var cache: [String: (data: Data, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Generic Request
    
    func request<T: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        cacheKey: String? = nil
    ) async throws -> T {
        // Check cache
        if let cacheKey = cacheKey,
           let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            return try decoder.decode(T.self, from: cached.data)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            // Cache successful response
            if let cacheKey = cacheKey {
                cache[cacheKey] = (data, Date())
            }
            
            // Debug: Log raw JSON response (first 1000 chars)
            if let jsonString = String(data: data, encoding: .utf8) {
                let preview = String(jsonString.prefix(1000))
                print("🔍 [NetworkManager] Raw JSON response: \(preview)")
            }
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("🔴 [NetworkManager] Decoding error: \(error)")
                throw NetworkError.decodingError(error)
            }
            
        case 401:
            throw NetworkError.unauthorized
        case 404:
            throw NetworkError.notFound
        case 429:
            throw NetworkError.rateLimited
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - POST Request
    
    func post<T: Decodable, B: Encodable>(
        url: URL,
        body: B,
        headers: [String: String] = [:]
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Raw Data Request
    
    func fetchData(url: URL, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return data
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cache.removeAll()
    }
    
    func clearCache(forKey key: String) {
        cache.removeValue(forKey: key)
    }
}
