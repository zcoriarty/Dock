//
//  PropertyDetailsTabView.swift
//  Dock
//
//  Property-specific listing details tab
//

import SwiftUI

struct PropertyDetailsTabView: View {
    let property: Property
    let listingDetails: PropertyData?
    let cardBackground: Color
    
    var body: some View {
        VStack(spacing: 24) {
            priceHistorySection
            lotDetailsSection
            descriptionSection
            listingDetailsSection
            taxInformationSection
        }
    }
    
    private var priceHistorySection: some View {
        ModernSection(title: "Price History", background: cardBackground) {
            detailList(rows: priceHistoryRows)
        }
    }
    
    private var lotDetailsSection: some View {
        ModernSection(title: "Lot Details", background: cardBackground) {
            detailList(rows: lotDetailRows)
        }
    }
    
    private var descriptionSection: some View {
        ModernSection(title: "Description", background: cardBackground) {
            Text(descriptionText ?? "No description available yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }
    
    private var listingDetailsSection: some View {
        ModernSection(title: "Property Listing Details", background: cardBackground) {
            detailList(rows: listingDetailRows)
        }
    }
    
    private var taxInformationSection: some View {
        ModernSection(title: "Tax Information", background: cardBackground) {
            detailList(rows: taxDetailRows)
        }
    }
    
    private var priceHistoryRows: [PropertyDetailRowData] {
        [
            .init(title: "Current List Price", value: property.askingPrice.asCurrency),
            .init(title: "List Date", value: formattedDateValue(listingDetails?.listDate)),
            .init(title: "Last Sold Price", value: currencyValue(listingDetails?.soldPrice)),
            .init(title: "Last Sold Date", value: formattedDateValue(listingDetails?.lastSoldDate))
        ]
    }
    
    private var lotDetailRows: [PropertyDetailRowData] {
        [
            .init(title: "Property Type", value: property.propertyType.rawValue),
            .init(title: "Year Built", value: intValue(property.yearBuilt, fallback: "Not available")),
            .init(title: "Square Feet", value: intValue(property.squareFeet, suffix: "sq ft")),
            .init(title: "Lot Size", value: intValue(property.lotSize, suffix: "sq ft")),
            .init(title: "Units", value: intValue(property.unitCount)),
            .init(title: "Stories", value: optionalIntValue(listingDetails?.stories)),
            .init(title: "Garage Spaces", value: optionalIntValue(listingDetails?.parkingGarage))
        ]
    }
    
    private var listingDetailRows: [PropertyDetailRowData] {
        [
            .init(title: "Listing Status", value: listingStatusValue(listingDetails?.status)),
            .init(title: "MLS ID", value: stringValue(listingDetails?.mlsId)),
            .init(title: "Source", value: stringValue(listingDetails?.source?.capitalized)),
            .init(title: "Days on Market", value: optionalIntValue(listingDetails?.daysOnMarket, suffix: "days")),
            .init(title: "Price per Sq Ft", value: currencyValue(listingDetails?.pricePerSqft)),
            .init(title: "HOA Fee", value: currencyValue(listingDetails?.hoaFee)),
            .init(title: "Agent", value: stringValue(listingDetails?.agentName)),
            .init(title: "Broker", value: stringValue(listingDetails?.brokerName))
        ]
    }
    
    private var taxDetailRows: [PropertyDetailRowData] {
        let assessedValue = resolvedAssessedValue
        let annualTaxes = resolvedAnnualTaxes
        
        return [
            .init(title: "Assessed Value", value: currencyValue(assessedValue)),
            .init(title: "Annual Taxes", value: currencyValue(annualTaxes)),
            .init(title: "Tax Rate", value: taxRateValue(assessedValue: assessedValue, annualTaxes: annualTaxes))
        ]
    }
    
    private var descriptionText: String? {
        let trimmed = listingDetails?.description?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
    
    private var resolvedAssessedValue: Double? {
        let listingValue = listingDetails?.taxAssessedValue
        return (listingValue ?? 0) > 0 ? listingValue : property.taxAssessedValue
    }
    
    private var resolvedAnnualTaxes: Double? {
        let listingValue = listingDetails?.annualTaxes
        return (listingValue ?? 0) > 0 ? listingValue : property.annualTaxes
    }
    
    private func detailList(rows: [PropertyDetailRowData]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                PropertyDetailRow(title: row.title, value: row.value)
                if index < rows.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
    }
    
    private func formattedDateValue(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Not available"
        }
        
        if let formatted = formattedDateString(value) {
            return formatted
        }
        
        return value
    }
    
    private func formattedDateString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        if let date = isoFormatter.date(from: trimmed) {
            return date.shortFormat
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: trimmed) {
            return date.shortFormat
        }
        
        return nil
    }
    
    private func stringValue(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : "Not available"
    }
    
    private func intValue(_ value: Int, fallback: String = "Not available") -> String {
        value > 0 ? value.withCommas : fallback
    }
    
    private func intValue(_ value: Int, suffix: String) -> String {
        guard value > 0 else { return "Not available" }
        return "\(value.withCommas) \(suffix)"
    }
    
    private func optionalIntValue(_ value: Int?, suffix: String? = nil) -> String {
        guard let value, value > 0 else { return "Not available" }
        if let suffix {
            return "\(value.withCommas) \(suffix)"
        }
        return value.withCommas
    }
    
    private func currencyValue(_ value: Double?) -> String {
        guard let value, value > 0 else { return "Not available" }
        return value.asCurrency
    }
    
    private func listingStatusValue(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return "Not available" }
        return trimmed.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    private func taxRateValue(assessedValue: Double?, annualTaxes: Double?) -> String {
        guard let assessedValue, let annualTaxes, assessedValue > 0, annualTaxes > 0 else {
            return "Not available"
        }
        return (annualTaxes / assessedValue).asPercent(decimals: 2)
    }
}

private struct PropertyDetailRowData: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct PropertyDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer(minLength: 12)
            
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
