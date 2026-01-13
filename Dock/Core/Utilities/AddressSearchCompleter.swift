//
//  AddressSearchCompleter.swift
//  Dock
//
//  Address autocomplete using Apple's MKLocalSearchCompleter
//

import Foundation
import MapKit
import Combine

/// Address suggestion model
struct AddressSuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String       // Street address
    let subtitle: String    // City, State ZIP
    let completion: MKLocalSearchCompletion
    
    var fullAddress: String {
        if subtitle.isEmpty {
            return title
        }
        return "\(title), \(subtitle)"
    }
    
    static func == (lhs: AddressSuggestion, rhs: AddressSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

/// Observable class that handles address autocomplete using MapKit
@MainActor
@Observable
final class AddressSearchCompleter: NSObject {
    var suggestions: [AddressSuggestion] = []
    var isSearching: Bool = false
    var searchQuery: String = "" {
        didSet {
            searchCompleter.queryFragment = searchQuery
        }
    }
    
    private let searchCompleter = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address
        // Focus on addresses, not points of interest
        searchCompleter.pointOfInterestFilter = .excludingAll
    }
    
    /// Get detailed address components from a suggestion
    func getAddressDetails(for suggestion: AddressSuggestion) async throws -> AddressDetails {
        let searchRequest = MKLocalSearch.Request(completion: suggestion.completion)
        let search = MKLocalSearch(request: searchRequest)
        
        let response = try await search.start()
        
        guard let mapItem = response.mapItems.first else {
            throw AddressSearchError.noResults
        }
        
        let placemark = mapItem.placemark
        
        return AddressDetails(
            streetAddress: placemark.thoroughfare.map { number in
                if let subThoroughfare = placemark.subThoroughfare {
                    return "\(subThoroughfare) \(number)"
                }
                return number
            } ?? suggestion.title,
            city: placemark.locality ?? "",
            state: placemark.administrativeArea ?? "",
            zipCode: placemark.postalCode ?? "",
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude
        )
    }
    
    func clearSuggestions() {
        suggestions = []
        searchQuery = ""
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension AddressSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results.map { result in
                AddressSuggestion(
                    title: result.title,
                    subtitle: result.subtitle,
                    completion: result
                )
            }
            self.isSearching = false
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
            // Silently handle errors - user is still typing
        }
    }
}

// MARK: - Address Details

struct AddressDetails {
    let streetAddress: String
    let city: String
    let state: String
    let zipCode: String
    let latitude: Double
    let longitude: Double
    
    var fullAddress: String {
        "\(streetAddress), \(city), \(state) \(zipCode)"
    }
}

// MARK: - Errors

enum AddressSearchError: LocalizedError {
    case noResults
    case searchFailed
    
    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No address found"
        case .searchFailed:
            return "Address search failed"
        }
    }
}
