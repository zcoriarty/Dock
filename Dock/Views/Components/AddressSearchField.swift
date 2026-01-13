//
//  AddressSearchField.swift
//  Dock
//
//  Address input field with autocomplete suggestions
//

import SwiftUI

struct AddressSearchField: View {
    let title: String
    @Binding var selectedAddress: String
    var autoFocus: Bool = false
    let onAddressSelected: (AddressSuggestion) -> Void
    
    @State private var searchCompleter = AddressSearchCompleter()
    @State private var showSuggestions: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Start typing an address...", text: $searchCompleter.searchQuery)
                        .textContentType(.fullStreetAddress)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .onChange(of: searchCompleter.searchQuery) { _, newValue in
                            showSuggestions = !newValue.isEmpty && isFocused
                        }
                        .onChange(of: isFocused) { _, focused in
                            if focused {
                                showSuggestions = !searchCompleter.searchQuery.isEmpty
                                Task { @MainActor in
                                    HapticManager.shared.editField()
                                }
                            } else {
                                // Delay hiding so tap on suggestion can register
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showSuggestions = false
                                }
                            }
                        }
                    
                    if !searchCompleter.searchQuery.isEmpty {
                        Button {
                            searchCompleter.clearSuggestions()
                            selectedAddress = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !selectedAddress.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 2)
                }
            }
            
            // Suggestions dropdown
            if showSuggestions && !searchCompleter.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchCompleter.suggestions.prefix(5)) { suggestion in
                        Button {
                            selectSuggestion(suggestion)
                        } label: {
                            HStack {
                                Text(suggestion.fullAddress)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if suggestion.id != searchCompleter.suggestions.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSuggestions)
        .animation(.easeInOut(duration: 0.2), value: searchCompleter.suggestions.count)
        .task {
            if autoFocus {
                // Wait for the sheet to fully present before focusing
                try? await Task.sleep(for: .milliseconds(600))
                isFocused = true
            }
        }
    }
    
    private func selectSuggestion(_ suggestion: AddressSuggestion) {
        searchCompleter.searchQuery = suggestion.fullAddress
        selectedAddress = suggestion.fullAddress
        showSuggestions = false
        isFocused = false
        HapticManager.shared.selection()
        onAddressSelected(suggestion)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        AddressSearchField(
            title: "Property Address",
            selectedAddress: .constant("")
        ) { suggestion in
            print("Selected: \(suggestion.fullAddress)")
        }
        .padding()
        
        Spacer()
    }
}
