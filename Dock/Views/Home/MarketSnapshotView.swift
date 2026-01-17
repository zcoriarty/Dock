//
//  MarketSnapshotView.swift
//  Dock
//
//  Market snapshot table and supporting views
//

import SwiftUI

private enum MarketSnapshotLayout {
    static let averageRentWidth: CGFloat = 70
    static let medianRentWidth: CGFloat = 70
    static let newListingsWidth: CGFloat = 56
}

struct MarketSnapshotSection: View {
    let summaries: [CityMarketSummary]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {            
            VStack(alignment: .leading, spacing: 0) {
                MarketSnapshotHeaderRow()
                    .padding(.bottom, 8)
                
                if summaries.isEmpty {
                    MarketSnapshotSkeletonRow()
                    MarketSnapshotSkeletonRow()
                } else {
                    ForEach(summaries) { summary in
                        MarketSnapshotRow(summary: summary)
                    }
                }
            }
            .padding(.horizontal)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Updating...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
        .padding(.top, 12)
    }
}

private struct MarketSnapshotHeaderRow: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Market")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Avg Rent")
                .frame(width: MarketSnapshotLayout.averageRentWidth, alignment: .leading)
            
            Text("Median")
                .frame(width: MarketSnapshotLayout.medianRentWidth, alignment: .leading)
            
            Text("New (7d)")
                .frame(width: MarketSnapshotLayout.newListingsWidth, alignment: .leading)
        }
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundStyle(.tertiary)
    }
}

struct MarketInsightSummary: View {
    let summaries: [CityMarketSummary]
    
    @State private var isExpanded: Bool = false
    
    private var insightText: String {
        guard !summaries.isEmpty else { return "" }
        
        var lines: [String] = []
        
        for summary in summaries {
            var cityHighlight = "**\(summary.city)**: "
            var details: [String] = []
            
            if let avg = summary.averageRent, avg > 0 {
                details.append("avg rent \(avg.asCurrency)")
            }
            if let median = summary.medianRent, median > 0, summary.averageRent != summary.medianRent {
                details.append("median \(median.asCurrency)")
            }
            if let listings = summary.newListingsLastWeek, listings > 0 {
                if listings > 100 {
                    details.append("\(listings) new listings (very active)")
                } else if listings > 50 {
                    details.append("\(listings) new listings (active)")
                } else {
                    details.append("\(listings) new listings")
                }
            }
            
            if !details.isEmpty {
                cityHighlight += details.joined(separator: ", ")
                lines.append(cityHighlight)
            }
        }
        
        if summaries.count > 1 {
            let marketsWithRent = summaries.filter { $0.medianRent != nil && $0.medianRent! > 0 }
            if let cheapest = marketsWithRent.min(by: { $0.medianRent! < $1.medianRent! }),
               let expensive = marketsWithRent.max(by: { $0.medianRent! < $1.medianRent! }),
               cheapest.city != expensive.city,
               let cheapRent = cheapest.medianRent,
               let expensiveRent = expensive.medianRent {
                let diff = expensiveRent - cheapRent
                if diff > 100 {
                    lines.append("**\(cheapest.city)** is \(diff.asCurrency)/mo cheaper than **\(expensive.city)**")
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    private var hasMoreContent: Bool {
        insightText.components(separatedBy: "\n").count > 3
    }
    
    var body: some View {
        if !insightText.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(insightText))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if hasMoreContent {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "Show less" : "Show more")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if hasMoreContent {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }
        }
    }
}

struct MarketSnapshotRow: View {
    let summary: CityMarketSummary
    
    private var averageRentText: String {
        guard let value = summary.averageRent, value > 0 else { return "—" }
        return value.asCurrency
    }
    
    private var medianRentText: String {
        guard let value = summary.medianRent, value > 0 else { return "—" }
        return value.asCurrency
    }
    
    private var newListingsText: String {
        guard let value = summary.newListingsLastWeek else { return "—" }
        return "\(value)"
    }
    
    private var isHotMarket: Bool {
        (summary.newListingsLastWeek ?? 0) > 50
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Text("\(summary.city), \(summary.state)")
                .font(.system(.subheadline, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(averageRentText)
                .font(.system(.subheadline, design: .rounded, weight: .regular))
                .monospacedDigit()
                .frame(width: MarketSnapshotLayout.averageRentWidth, alignment: .leading)
            
            Text(medianRentText)
                .font(.system(.subheadline, design: .rounded, weight: .regular))
                .monospacedDigit()
                .frame(width: MarketSnapshotLayout.medianRentWidth, alignment: .leading)
            
            HStack(spacing: 3) {
                Text(newListingsText)
                    .font(.system(.subheadline, design: .rounded, weight: isHotMarket ? .semibold : .regular))
                    .foregroundStyle(isHotMarket ? .orange : .primary)
                if isHotMarket {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }
            .monospacedDigit()
            .frame(width: MarketSnapshotLayout.newListingsWidth, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

struct MarketSnapshotSkeletonRow: View {
    var body: some View {
        HStack(spacing: 0) {
            SkeletonView(height: 14)
                .frame(width: 90)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            SkeletonView(height: 14)
                .frame(width: 50)
                .frame(width: MarketSnapshotLayout.averageRentWidth, alignment: .leading)
            
            SkeletonView(height: 14)
                .frame(width: 50)
                .frame(width: MarketSnapshotLayout.medianRentWidth, alignment: .leading)
            
            SkeletonView(height: 14)
                .frame(width: 30)
                .frame(width: MarketSnapshotLayout.newListingsWidth, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}
