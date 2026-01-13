//
//  DealMetrics.swift
//  Dock
//
//  Calculated investment metrics organized in three layers
//

import Foundation
import SwiftUI

// MARK: - Deal Metrics

struct DealMetrics: Sendable {
    // Layer 1: Deal Economics
    let dealEconomics: DealEconomics
    
    // Layer 2: Market Support
    let marketSupport: MarketSupport
    
    // Layer 3: Risk Buffers
    let riskBuffers: RiskBuffers
    
    // Overall Assessment
    let overallScore: Double
    let recommendation: InvestmentRecommendation
    let scoredMetrics: [ScoredMetric]
}

// MARK: - Layer 1: Deal Economics

struct DealEconomics: Sendable {
    // Income
    let grossPotentialRent: Double
    let effectiveGrossIncome: Double
    let vacancyLoss: Double
    
    // Expenses
    let totalOperatingExpenses: Double
    let expenseBreakdown: ExpenseBreakdown
    
    // NOI
    let netOperatingIncome: Double
    
    // Financing
    let monthlyDebtService: Double
    let annualDebtService: Double
    let dscr: Double
    
    // Returns
    let annualCashFlow: Double
    let monthlyCashFlow: Double
    let cashOnCashReturn: Double
    let inPlaceCapRate: Double
    let stabilizedCapRate: Double
    
    // Price Metrics
    let pricePerUnit: Double
    let pricePerSquareFoot: Double
}

struct ExpenseBreakdown: Sendable {
    let taxes: Double
    let insurance: Double
    let management: Double
    let repairs: Double
    let capexReserve: Double
    let utilities: Double
    let other: Double
    
    var total: Double {
        taxes + insurance + management + repairs + capexReserve + utilities + other
    }
    
    var expenseRatio: Double
}

// MARK: - Layer 2: Market Support

struct MarketSupport: Sendable {
    let rentGrowth: MarketIndicator
    let priceAppreciation: MarketIndicator
    let vacancyTrend: MarketIndicator
    let daysOnMarket: MarketIndicator
    let supplyTrend: MarketIndicator
    let demandIndicator: MarketIndicator
}

struct MarketIndicator: Sendable {
    let value: Double
    let displayValue: String
    let trend: TrendDirection
    let signal: SignalStrength
    let description: String
}

enum TrendDirection: String, Sendable {
    case up = "arrow.up"
    case down = "arrow.down"
    case stable = "minus"
    case unknown = "questionmark"
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        case .unknown: return .gray
        }
    }
}

enum SignalStrength: String, Sendable {
    case strong = "Strong"
    case moderate = "Moderate"
    case weak = "Weak"
    case neutral = "Neutral"
    case unknown = "Unknown"
    
    var color: Color {
        switch self {
        case .strong: return .green
        case .moderate: return .yellow
        case .weak: return .red
        case .neutral: return .gray
        case .unknown: return .gray
        }
    }
}

// MARK: - Layer 3: Risk Buffers

struct RiskBuffers: Sendable {
    let breakEvenOccupancy: Double
    let sensitivityAnalysis: SensitivityAnalysis
    let stressTestResults: StressTestResults
}

struct SensitivityAnalysis: Sendable {
    // Rent sensitivity (±10%)
    let rentUp10: SensitivityResult
    let rentDown10: SensitivityResult
    
    // Rate sensitivity (±1%)
    let rateUp1: SensitivityResult
    let rateDown1: SensitivityResult
    
    // Exit cap sensitivity (±50 bps)
    let exitCapUp50bps: SensitivityResult
    let exitCapDown50bps: SensitivityResult
}

struct SensitivityResult: Sendable {
    let label: String
    let noi: Double
    let cashFlow: Double
    let cashOnCash: Double
    let dscr: Double
    let deltaFromBase: Double
}

struct StressTestResults: Sendable {
    let worstCaseCashFlow: Double
    let maxVacancyBeforeNegative: Double
    let maxRateBeforeNegative: Double
    let cushionToBreakEven: Double
}

// MARK: - Scoring

struct ScoredMetric: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let value: Double
    let displayValue: String
    let threshold: Double
    let displayThreshold: String
    let score: MetricScore
    let category: MetricCategory
    let importance: MetricImportance
    
    var color: Color {
        score.color
    }
}

enum MetricScore: String, Sendable {
    case exceeds = "Exceeds"
    case meets = "Meets"
    case borderline = "Borderline"
    case fails = "Fails"
    
    var color: Color {
        switch self {
        case .exceeds: return .green
        case .meets: return Color(hex: "#34C759") ?? .green
        case .borderline: return .yellow
        case .fails: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .exceeds: return "checkmark.circle.fill"
        case .meets: return "checkmark.circle"
        case .borderline: return "exclamationmark.triangle.fill"
        case .fails: return "xmark.circle.fill"
        }
    }
}

enum MetricCategory: String, CaseIterable, Sendable {
    case dealEconomics = "Deal Economics"
    case marketSupport = "Market Support"
    case riskBuffers = "Risk Buffers"
}

enum MetricImportance: Int, Sendable {
    case critical = 3
    case high = 2
    case medium = 1
    
    var weight: Double {
        switch self {
        case .critical: return 1.5
        case .high: return 1.0
        case .medium: return 0.5
        }
    }
}

// MARK: - Investment Recommendation

enum InvestmentRecommendation: String, Sendable {
    case strongBuy = "Strong Buy"
    case buy = "Buy"
    case hold = "Hold"
    case caution = "Caution"
    case pass = "Pass"
    
    var color: Color {
        switch self {
        case .strongBuy: return .green
        case .buy: return Color(hex: "#34C759") ?? .green
        case .hold: return .yellow
        case .caution: return .orange
        case .pass: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .strongBuy: return "star.circle.fill"
        case .buy: return "checkmark.seal.fill"
        case .hold: return "pause.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .pass: return "xmark.octagon.fill"
        }
    }
    
    var description: String {
        switch self {
        case .strongBuy:
            return "Excellent opportunity. All key metrics exceed targets with strong market support."
        case .buy:
            return "Good investment. Metrics meet targets with acceptable risk profile."
        case .hold:
            return "Borderline deal. Some metrics meet targets but others need attention."
        case .caution:
            return "Proceed carefully. Multiple metrics below target or significant risks present."
        case .pass:
            return "Not recommended. Key metrics fail to meet minimum thresholds."
        }
    }
}
