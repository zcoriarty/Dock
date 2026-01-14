//
//  MarketRateItem.swift
//  Dock
//
//  Model for displaying market rates in the auto-scrolling header
//

import SwiftUI

struct MarketRateItem: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let change: String
    let changePercent: Double
    let icon: String
    let historicalData: [Double]
    
    var changeColor: Color {
        if changePercent > 0 {
            return .red // Rates going up is generally bad for investors
        } else if changePercent < 0 {
            return .green // Rates going down is good
        } else {
            return .secondary
        }
    }
    
    var changeIcon: String {
        if changePercent > 0 {
            return "arrow.up.right"
        } else if changePercent < 0 {
            return "arrow.down.right"
        } else {
            return "minus"
        }
    }
}

// MARK: - Sample Data for Preview

extension MarketRateItem {
    static var sampleRates: [MarketRateItem] {
        [
            MarketRateItem(
                name: "30-Yr Fixed",
                value: "6.95%",
                change: "+0.12%",
                changePercent: 0.12,
                icon: "house.fill",
                historicalData: [6.5, 6.6, 6.7, 6.65, 6.8, 6.75, 6.9, 6.95]
            ),
            MarketRateItem(
                name: "15-Yr Fixed",
                value: "6.25%",
                change: "-0.05%",
                changePercent: -0.05,
                icon: "house",
                historicalData: [6.4, 6.35, 6.3, 6.28, 6.25, 6.3, 6.28, 6.25]
            ),
            MarketRateItem(
                name: "10-Yr Treasury",
                value: "4.25%",
                change: "+0.08%",
                changePercent: 0.08,
                icon: "banknote.fill",
                historicalData: [4.1, 4.15, 4.18, 4.2, 4.22, 4.19, 4.23, 4.25]
            ),
            MarketRateItem(
                name: "Prime Rate",
                value: "8.50%",
                change: "0.00%",
                changePercent: 0.0,
                icon: "building.columns.fill",
                historicalData: [8.5, 8.5, 8.5, 8.5, 8.5, 8.5, 8.5, 8.5]
            )
        ]
    }
}

// MARK: - Rate Data Conversion

extension RateData {
    /// Convert RateData to displayable MarketRateItems
    func toMarketRateItems(previousRates: RateData? = nil) -> [MarketRateItem] {
        var items: [MarketRateItem] = []
        
        // 30-Year Fixed
        if let rate30 = rate30YrFixed {
            let prev30 = previousRates?.rate30YrFixed ?? rate30
            let change = (rate30 - prev30) * 100
            items.append(MarketRateItem(
                name: "30-Yr Fixed",
                value: String(format: "%.2f%%", rate30 * 100),
                change: String(format: "%+.2f%%", change),
                changePercent: change,
                icon: "house.fill",
                historicalData: generateHistoricalData(current: rate30 * 100, variance: 0.3)
            ))
        }
        
        // 15-Year Fixed
        if let rate15 = rate15YrFixed {
            let prev15 = previousRates?.rate15YrFixed ?? rate15
            let change = (rate15 - prev15) * 100
            items.append(MarketRateItem(
                name: "15-Yr Fixed",
                value: String(format: "%.2f%%", rate15 * 100),
                change: String(format: "%+.2f%%", change),
                changePercent: change,
                icon: "house",
                historicalData: generateHistoricalData(current: rate15 * 100, variance: 0.25)
            ))
        }
        
        // 10-Year Treasury
        if let treasury = treasuryRate10Yr {
            let prevTreasury = previousRates?.treasuryRate10Yr ?? treasury
            let change = (treasury - prevTreasury) * 100
            items.append(MarketRateItem(
                name: "10-Yr Treasury",
                value: String(format: "%.2f%%", treasury * 100),
                change: String(format: "%+.2f%%", change),
                changePercent: change,
                icon: "banknote.fill",
                historicalData: generateHistoricalData(current: treasury * 100, variance: 0.15)
            ))
        }
        
        // Prime Rate
        if let prime = primerate {
            let prevPrime = previousRates?.primerate ?? prime
            let change = (prime - prevPrime) * 100
            items.append(MarketRateItem(
                name: "Prime Rate",
                value: String(format: "%.2f%%", prime * 100),
                change: String(format: "%+.2f%%", change),
                changePercent: change,
                icon: "building.columns.fill",
                historicalData: generateHistoricalData(current: prime * 100, variance: 0.1)
            ))
        }
        
        // 5/1 ARM
        if let arm5 = rate5_1ARM {
            let prevArm = previousRates?.rate5_1ARM ?? arm5
            let change = (arm5 - prevArm) * 100
            items.append(MarketRateItem(
                name: "5/1 ARM",
                value: String(format: "%.2f%%", arm5 * 100),
                change: String(format: "%+.2f%%", change),
                changePercent: change,
                icon: "arrow.triangle.2.circlepath",
                historicalData: generateHistoricalData(current: arm5 * 100, variance: 0.2)
            ))
        }
        
        return items
    }
    
    /// Generate simulated historical data for mini charts
    private func generateHistoricalData(current: Double, variance: Double) -> [Double] {
        var data: [Double] = []
        var value = current - variance * 2
        
        for i in 0..<8 {
            // Trend towards current value
            let progress = Double(i) / 7.0
            let target = current
            let randomVariance = Double.random(in: -variance...variance) * (1 - progress)
            value = value + (target - value) * 0.3 + randomVariance
            data.append(max(0, value))
        }
        
        // Ensure last value matches current
        data[7] = current
        return data
    }
}
