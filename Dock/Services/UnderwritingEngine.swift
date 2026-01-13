//
//  UnderwritingEngine.swift
//  Dock
//
//  Core calculation engine for investment underwriting
//

import Foundation

enum UnderwritingEngine {
    
    // MARK: - Main Calculation
    
    static func calculateMetrics(for property: Property) -> DealMetrics {
        let dealEconomics = calculateDealEconomics(for: property)
        let marketSupport = calculateMarketSupport(for: property)
        let riskBuffers = calculateRiskBuffers(for: property, economics: dealEconomics)
        let scoredMetrics = scoreAllMetrics(property: property, economics: dealEconomics, market: marketSupport, risk: riskBuffers)
        let overallScore = calculateOverallScore(metrics: scoredMetrics)
        let recommendation = determineRecommendation(score: overallScore, metrics: scoredMetrics)
        
        return DealMetrics(
            dealEconomics: dealEconomics,
            marketSupport: marketSupport,
            riskBuffers: riskBuffers,
            overallScore: overallScore,
            recommendation: recommendation,
            scoredMetrics: scoredMetrics
        )
    }
    
    // MARK: - Layer 1: Deal Economics
    
    static func calculateDealEconomics(for property: Property) -> DealEconomics {
        // Income
        let monthlyRent = property.estimatedTotalRent > 0 ? property.estimatedTotalRent : property.estimatedRentPerUnit * Double(property.unitCount)
        let grossPotentialRent = monthlyRent * 12
        let vacancyLoss = grossPotentialRent * property.vacancyRate
        let effectiveGrossIncome = grossPotentialRent - vacancyLoss
        
        // Expenses
        let expenseBreakdown = calculateExpenses(for: property, effectiveGrossIncome: effectiveGrossIncome)
        let totalOperatingExpenses = expenseBreakdown.total
        
        // NOI
        let netOperatingIncome = effectiveGrossIncome - totalOperatingExpenses
        
        // Financing
        let financing = property.financing
        let purchasePrice = financing.purchasePrice > 0 ? financing.purchasePrice : property.askingPrice
        let loanAmount = financing.loanAmount > 0 ? financing.loanAmount : purchasePrice * financing.ltv
        
        let monthlyDebtService = RateService.shared.calculateMonthlyPayment(
            principal: loanAmount,
            annualRate: financing.interestRate,
            termYears: financing.loanTermYears,
            isInterestOnly: financing.isInterestOnly
        )
        let annualDebtService = monthlyDebtService * 12
        
        // Returns
        let annualCashFlow = netOperatingIncome - annualDebtService
        let monthlyCashFlow = annualCashFlow / 12
        
        let totalCashRequired = financing.totalCashRequired > 0 ? financing.totalCashRequired : (purchasePrice - loanAmount) + financing.closingCosts
        let cashOnCashReturn = totalCashRequired > 0 ? annualCashFlow / totalCashRequired : 0
        
        let inPlaceCapRate = purchasePrice > 0 ? netOperatingIncome / purchasePrice : 0
        
        // Stabilized cap rate uses market rent
        let stabilizedGPR = (property.marketData?.medianRent ?? monthlyRent) * 12 * Double(property.unitCount)
        let stabilizedEGI = stabilizedGPR * (1 - property.vacancyRate)
        let stabilizedNOI = stabilizedEGI - totalOperatingExpenses
        let stabilizedCapRate = purchasePrice > 0 ? stabilizedNOI / purchasePrice : 0
        
        let dscr = annualDebtService > 0 ? netOperatingIncome / annualDebtService : 0
        
        let pricePerUnit = property.unitCount > 0 ? purchasePrice / Double(property.unitCount) : purchasePrice
        let pricePerSquareFoot = property.squareFeet > 0 ? purchasePrice / Double(property.squareFeet) : 0
        
        return DealEconomics(
            grossPotentialRent: grossPotentialRent,
            effectiveGrossIncome: effectiveGrossIncome,
            vacancyLoss: vacancyLoss,
            totalOperatingExpenses: totalOperatingExpenses,
            expenseBreakdown: expenseBreakdown,
            netOperatingIncome: netOperatingIncome,
            monthlyDebtService: monthlyDebtService,
            annualDebtService: annualDebtService,
            dscr: dscr,
            annualCashFlow: annualCashFlow,
            monthlyCashFlow: monthlyCashFlow,
            cashOnCashReturn: cashOnCashReturn,
            inPlaceCapRate: inPlaceCapRate,
            stabilizedCapRate: stabilizedCapRate,
            pricePerUnit: pricePerUnit,
            pricePerSquareFoot: pricePerSquareFoot
        )
    }
    
    // MARK: - Expense Calculation
    
    static func calculateExpenses(for property: Property, effectiveGrossIncome: Double) -> ExpenseBreakdown {
        let taxes = property.annualTaxes
        let insurance = property.insuranceAnnual > 0 ? property.insuranceAnnual : estimateInsurance(for: property)
        let management = effectiveGrossIncome * property.managementFeePercent
        let repairs = property.repairsPerUnit * Double(property.unitCount)
        let capexReserve = calculateCapexReserve(for: property)
        let utilities: Double = 0 // Typically tenant-paid for residential
        let other = property.otherExpenses
        
        let total = taxes + insurance + management + repairs + capexReserve + utilities + other
        let expenseRatio = effectiveGrossIncome > 0 ? total / effectiveGrossIncome : 0
        
        return ExpenseBreakdown(
            taxes: taxes,
            insurance: insurance,
            management: management,
            repairs: repairs,
            capexReserve: capexReserve,
            utilities: utilities,
            other: other,
            expenseRatio: expenseRatio
        )
    }
    
    static func estimateInsurance(for property: Property) -> Double {
        // Use insurance service estimate
        let estimate = InsuranceService.shared.estimateInsurance(
            propertyValue: property.askingPrice,
            squareFeet: property.squareFeet,
            yearBuilt: property.yearBuilt,
            state: property.state,
            propertyType: property.propertyType
        )
        return estimate.totalAnnualCost
    }
    
    static func calculateCapexReserve(for property: Property) -> Double {
        // Rule of thumb: $250-500 per unit per year for capex
        let age = Calendar.current.component(.year, from: Date()) - property.yearBuilt
        let baseReserve: Double = 300
        
        // Increase for older properties
        let ageMultiplier: Double = {
            switch age {
            case 0...10: return 0.75
            case 11...20: return 1.0
            case 21...30: return 1.25
            case 31...50: return 1.5
            default: return 2.0
            }
        }()
        
        return baseReserve * ageMultiplier * Double(property.unitCount)
    }
    
    // MARK: - Layer 2: Market Support
    
    static func calculateMarketSupport(for property: Property) -> MarketSupport {
        let marketData = property.marketData
        
        let rentGrowth = MarketIndicator(
            value: marketData?.rentGrowthYoY ?? 0,
            displayValue: (marketData?.rentGrowthYoY ?? 0).asPercent(),
            trend: determineTrend(value: marketData?.rentGrowthYoY, isPositiveGood: true),
            signal: determineRentGrowthSignal(marketData?.rentGrowthYoY),
            description: "Year-over-year rent growth in submarket"
        )
        
        let priceAppreciation = MarketIndicator(
            value: marketData?.priceAppreciationYoY ?? 0,
            displayValue: (marketData?.priceAppreciationYoY ?? 0).asPercent(),
            trend: determineTrend(value: marketData?.priceAppreciationYoY, isPositiveGood: true),
            signal: determinePriceAppreciationSignal(marketData?.priceAppreciationYoY),
            description: "Year-over-year home price appreciation"
        )
        
        let vacancyTrend = MarketIndicator(
            value: marketData?.vacancyRate ?? 0,
            displayValue: (marketData?.vacancyRate ?? 0).asPercent(),
            trend: determineTrend(value: marketData?.vacancyRate, isPositiveGood: false),
            signal: determineVacancySignal(marketData?.vacancyRate),
            description: "Current submarket vacancy rate"
        )
        
        let daysOnMarket = MarketIndicator(
            value: Double(marketData?.daysOnMarket ?? 0),
            displayValue: "\(marketData?.daysOnMarket ?? 0) days",
            trend: determineTrend(value: marketData?.daysOnMarket.map { Double($0) }, isPositiveGood: false),
            signal: determineDOMSignal(marketData?.daysOnMarket),
            description: "Average days on market"
        )
        
        let supplyTrend = MarketIndicator(
            value: marketData?.inventoryMonths ?? 0,
            displayValue: String(format: "%.1f mo", marketData?.inventoryMonths ?? 0),
            trend: determineTrend(value: marketData?.inventoryMonths, isPositiveGood: false),
            signal: determineSupplySignal(marketData?.inventoryMonths),
            description: "Months of housing inventory"
        )
        
        let demandIndicator = MarketIndicator(
            value: marketData?.populationGrowth ?? 0,
            displayValue: (marketData?.populationGrowth ?? 0).asPercent(),
            trend: determineTrend(value: marketData?.populationGrowth, isPositiveGood: true),
            signal: determineDemandSignal(marketData?.populationGrowth),
            description: "Population growth trend"
        )
        
        return MarketSupport(
            rentGrowth: rentGrowth,
            priceAppreciation: priceAppreciation,
            vacancyTrend: vacancyTrend,
            daysOnMarket: daysOnMarket,
            supplyTrend: supplyTrend,
            demandIndicator: demandIndicator
        )
    }
    
    // MARK: - Layer 3: Risk Buffers
    
    static func calculateRiskBuffers(for property: Property, economics: DealEconomics) -> RiskBuffers {
        // Break-even occupancy
        let fixedCosts = economics.expenseBreakdown.taxes + economics.expenseBreakdown.insurance + economics.annualDebtService
        let variableCostsPerDollar = economics.expenseBreakdown.management / max(economics.effectiveGrossIncome, 1)
        let breakEvenOccupancy = economics.grossPotentialRent > 0 ? fixedCosts / (economics.grossPotentialRent * (1 - variableCostsPerDollar)) : 1.0
        
        // Sensitivity Analysis
        let sensitivityAnalysis = calculateSensitivity(for: property, baseEconomics: economics)
        
        // Stress Test
        let stressTestResults = calculateStressTest(for: property, economics: economics)
        
        return RiskBuffers(
            breakEvenOccupancy: min(breakEvenOccupancy, 1.0),
            sensitivityAnalysis: sensitivityAnalysis,
            stressTestResults: stressTestResults
        )
    }
    
    // MARK: - Sensitivity Analysis
    
    static func calculateSensitivity(for property: Property, baseEconomics: DealEconomics) -> SensitivityAnalysis {
        // Rent +10%
        var rentUp = property
        rentUp.estimatedRentPerUnit *= 1.10
        rentUp.estimatedTotalRent *= 1.10
        let rentUpEcon = calculateDealEconomics(for: rentUp)
        
        // Rent -10%
        var rentDown = property
        rentDown.estimatedRentPerUnit *= 0.90
        rentDown.estimatedTotalRent *= 0.90
        let rentDownEcon = calculateDealEconomics(for: rentDown)
        
        // Rate +1%
        var rateUp = property
        rateUp.financing.interestRate += 0.01
        let rateUpEcon = calculateDealEconomics(for: rateUp)
        
        // Rate -1%
        var rateDown = property
        rateDown.financing.interestRate -= 0.01
        let rateDownEcon = calculateDealEconomics(for: rateDown)
        
        // Exit cap +50bps (for valuation)
        let exitCapUp = baseEconomics.inPlaceCapRate + 0.005
        let valuationUp = exitCapUp > 0 ? baseEconomics.netOperatingIncome / exitCapUp : 0
        
        // Exit cap -50bps
        let exitCapDown = max(baseEconomics.inPlaceCapRate - 0.005, 0.01)
        let valuationDown = baseEconomics.netOperatingIncome / exitCapDown
        
        return SensitivityAnalysis(
            rentUp10: SensitivityResult(
                label: "Rent +10%",
                noi: rentUpEcon.netOperatingIncome,
                cashFlow: rentUpEcon.annualCashFlow,
                cashOnCash: rentUpEcon.cashOnCashReturn,
                dscr: rentUpEcon.dscr,
                deltaFromBase: rentUpEcon.annualCashFlow - baseEconomics.annualCashFlow
            ),
            rentDown10: SensitivityResult(
                label: "Rent -10%",
                noi: rentDownEcon.netOperatingIncome,
                cashFlow: rentDownEcon.annualCashFlow,
                cashOnCash: rentDownEcon.cashOnCashReturn,
                dscr: rentDownEcon.dscr,
                deltaFromBase: rentDownEcon.annualCashFlow - baseEconomics.annualCashFlow
            ),
            rateUp1: SensitivityResult(
                label: "Rate +1%",
                noi: rateUpEcon.netOperatingIncome,
                cashFlow: rateUpEcon.annualCashFlow,
                cashOnCash: rateUpEcon.cashOnCashReturn,
                dscr: rateUpEcon.dscr,
                deltaFromBase: rateUpEcon.annualCashFlow - baseEconomics.annualCashFlow
            ),
            rateDown1: SensitivityResult(
                label: "Rate -1%",
                noi: rateDownEcon.netOperatingIncome,
                cashFlow: rateDownEcon.annualCashFlow,
                cashOnCash: rateDownEcon.cashOnCashReturn,
                dscr: rateDownEcon.dscr,
                deltaFromBase: rateDownEcon.annualCashFlow - baseEconomics.annualCashFlow
            ),
            exitCapUp50bps: SensitivityResult(
                label: "Exit Cap +50bps",
                noi: baseEconomics.netOperatingIncome,
                cashFlow: baseEconomics.annualCashFlow,
                cashOnCash: baseEconomics.cashOnCashReturn,
                dscr: baseEconomics.dscr,
                deltaFromBase: valuationUp - property.askingPrice
            ),
            exitCapDown50bps: SensitivityResult(
                label: "Exit Cap -50bps",
                noi: baseEconomics.netOperatingIncome,
                cashFlow: baseEconomics.annualCashFlow,
                cashOnCash: baseEconomics.cashOnCashReturn,
                dscr: baseEconomics.dscr,
                deltaFromBase: valuationDown - property.askingPrice
            )
        )
    }
    
    // MARK: - Stress Test
    
    static func calculateStressTest(for property: Property, economics: DealEconomics) -> StressTestResults {
        // Worst case: rent -10%, vacancy +5%, expenses +10%
        var worstCase = property
        worstCase.estimatedRentPerUnit *= 0.90
        worstCase.estimatedTotalRent *= 0.90
        worstCase.vacancyRate = min(worstCase.vacancyRate + 0.05, 0.25)
        worstCase.repairsPerUnit *= 1.10
        let worstCaseEcon = calculateDealEconomics(for: worstCase)
        
        // Find max vacancy before negative cash flow
        var maxVacancy = property.vacancyRate
        while maxVacancy < 1.0 {
            var testProperty = property
            testProperty.vacancyRate = maxVacancy
            let testEcon = calculateDealEconomics(for: testProperty)
            if testEcon.annualCashFlow < 0 {
                break
            }
            maxVacancy += 0.01
        }
        
        // Find max rate before negative cash flow
        var maxRate = property.financing.interestRate
        while maxRate < 0.20 {
            var testProperty = property
            testProperty.financing.interestRate = maxRate
            let testEcon = calculateDealEconomics(for: testProperty)
            if testEcon.annualCashFlow < 0 {
                break
            }
            maxRate += 0.0025
        }
        
        // Cushion to break-even
        let cushion = economics.annualCashFlow / max(economics.grossPotentialRent, 1)
        
        return StressTestResults(
            worstCaseCashFlow: worstCaseEcon.annualCashFlow,
            maxVacancyBeforeNegative: maxVacancy,
            maxRateBeforeNegative: maxRate,
            cushionToBreakEven: cushion
        )
    }
    
    // MARK: - Scoring
    
    static func scoreAllMetrics(property: Property, economics: DealEconomics, market: MarketSupport, risk: RiskBuffers) -> [ScoredMetric] {
        let thresholds = property.thresholds
        var metrics: [ScoredMetric] = []
        
        // Deal Economics Metrics
        metrics.append(ScoredMetric(
            name: "Cap Rate",
            value: economics.inPlaceCapRate,
            displayValue: economics.inPlaceCapRate.asPercent(),
            threshold: thresholds.targetCapRate,
            displayThreshold: thresholds.targetCapRate.asPercent(),
            score: scoreCapRate(economics.inPlaceCapRate, target: thresholds.targetCapRate),
            category: .dealEconomics,
            importance: .critical
        ))
        
        metrics.append(ScoredMetric(
            name: "Cash-on-Cash",
            value: economics.cashOnCashReturn,
            displayValue: economics.cashOnCashReturn.asPercent(),
            threshold: thresholds.targetCashOnCash,
            displayThreshold: thresholds.targetCashOnCash.asPercent(),
            score: scoreCashOnCash(economics.cashOnCashReturn, target: thresholds.targetCashOnCash),
            category: .dealEconomics,
            importance: .critical
        ))
        
        metrics.append(ScoredMetric(
            name: "DSCR",
            value: economics.dscr,
            displayValue: String(format: "%.2fx", economics.dscr),
            threshold: thresholds.targetDSCR,
            displayThreshold: String(format: "%.2fx", thresholds.targetDSCR),
            score: scoreDSCR(economics.dscr, target: thresholds.targetDSCR),
            category: .dealEconomics,
            importance: .critical
        ))
        
        metrics.append(ScoredMetric(
            name: "NOI",
            value: economics.netOperatingIncome,
            displayValue: economics.netOperatingIncome.asCurrency,
            threshold: 0,
            displayThreshold: "> $0",
            score: economics.netOperatingIncome > 0 ? .meets : .fails,
            category: .dealEconomics,
            importance: .high
        ))
        
        // Market Support Metrics
        metrics.append(ScoredMetric(
            name: "Rent Growth",
            value: market.rentGrowth.value,
            displayValue: market.rentGrowth.displayValue,
            threshold: thresholds.minRentGrowth,
            displayThreshold: thresholds.minRentGrowth.asPercent(),
            score: scoreRentGrowth(market.rentGrowth.value, target: thresholds.minRentGrowth),
            category: .marketSupport,
            importance: .medium
        ))
        
        metrics.append(ScoredMetric(
            name: "Vacancy",
            value: market.vacancyTrend.value,
            displayValue: market.vacancyTrend.displayValue,
            threshold: thresholds.maxVacancy,
            displayThreshold: "< " + thresholds.maxVacancy.asPercent(),
            score: scoreVacancy(market.vacancyTrend.value, max: thresholds.maxVacancy),
            category: .marketSupport,
            importance: .medium
        ))
        
        // Risk Buffer Metrics
        metrics.append(ScoredMetric(
            name: "Break-even Occupancy",
            value: risk.breakEvenOccupancy,
            displayValue: risk.breakEvenOccupancy.asPercent(),
            threshold: thresholds.maxBreakEvenOccupancy,
            displayThreshold: "< " + thresholds.maxBreakEvenOccupancy.asPercent(),
            score: scoreBreakEven(risk.breakEvenOccupancy, max: thresholds.maxBreakEvenOccupancy),
            category: .riskBuffers,
            importance: .high
        ))
        
        metrics.append(ScoredMetric(
            name: "Worst Case Cash Flow",
            value: risk.stressTestResults.worstCaseCashFlow,
            displayValue: risk.stressTestResults.worstCaseCashFlow.asCurrency,
            threshold: 0,
            displayThreshold: "> $0",
            score: risk.stressTestResults.worstCaseCashFlow > 0 ? .meets : (risk.stressTestResults.worstCaseCashFlow > -5000 ? .borderline : .fails),
            category: .riskBuffers,
            importance: .high
        ))
        
        return metrics
    }
    
    // MARK: - Individual Scoring Functions
    
    static func scoreCapRate(_ value: Double, target: Double) -> MetricScore {
        if value >= target * 1.1 { return .exceeds }
        if value >= target { return .meets }
        if value >= target * 0.85 { return .borderline }
        return .fails
    }
    
    static func scoreCashOnCash(_ value: Double, target: Double) -> MetricScore {
        if value >= target * 1.25 { return .exceeds }
        if value >= target { return .meets }
        if value >= target * 0.75 { return .borderline }
        return .fails
    }
    
    static func scoreDSCR(_ value: Double, target: Double) -> MetricScore {
        if value >= target * 1.15 { return .exceeds }
        if value >= target { return .meets }
        if value >= target * 0.90 { return .borderline }
        return .fails
    }
    
    static func scoreRentGrowth(_ value: Double, target: Double) -> MetricScore {
        if value >= target * 1.5 { return .exceeds }
        if value >= target { return .meets }
        if value >= target * 0.5 { return .borderline }
        return .fails
    }
    
    static func scoreVacancy(_ value: Double, max: Double) -> MetricScore {
        if value <= max * 0.5 { return .exceeds }
        if value <= max { return .meets }
        if value <= max * 1.25 { return .borderline }
        return .fails
    }
    
    static func scoreBreakEven(_ value: Double, max: Double) -> MetricScore {
        if value <= max * 0.8 { return .exceeds }
        if value <= max { return .meets }
        if value <= max * 1.1 { return .borderline }
        return .fails
    }
    
    // MARK: - Overall Score
    
    static func calculateOverallScore(metrics: [ScoredMetric]) -> Double {
        guard !metrics.isEmpty else { return 0 }
        
        var totalWeightedScore: Double = 0
        var totalWeight: Double = 0
        
        for metric in metrics {
            let scoreValue: Double = {
                switch metric.score {
                case .exceeds: return 100
                case .meets: return 80
                case .borderline: return 50
                case .fails: return 20
                }
            }()
            
            totalWeightedScore += scoreValue * metric.importance.weight
            totalWeight += metric.importance.weight
        }
        
        return totalWeight > 0 ? totalWeightedScore / totalWeight : 0
    }
    
    // MARK: - Recommendation
    
    static func determineRecommendation(score: Double, metrics: [ScoredMetric]) -> InvestmentRecommendation {
        // Check for critical failures
        let criticalFails = metrics.filter { $0.importance == .critical && $0.score == .fails }
        if !criticalFails.isEmpty {
            return .pass
        }
        
        // Check for multiple borderline
        let borderlineCount = metrics.filter { $0.score == .borderline }.count
        let failCount = metrics.filter { $0.score == .fails }.count
        
        if score >= 85 && failCount == 0 {
            return .strongBuy
        } else if score >= 70 && failCount == 0 {
            return .buy
        } else if score >= 55 || (borderlineCount <= 2 && failCount <= 1) {
            return .hold
        } else if score >= 40 {
            return .caution
        } else {
            return .pass
        }
    }
    
    // MARK: - Helper Functions
    
    static func determineTrend(value: Double?, isPositiveGood: Bool) -> TrendDirection {
        guard let value = value else { return .unknown }
        
        if isPositiveGood {
            if value > 0.02 { return .up }
            if value < -0.02 { return .down }
            return .stable
        } else {
            if value > 0.02 { return .down }
            if value < -0.02 { return .up }
            return .stable
        }
    }
    
    static func determineRentGrowthSignal(_ value: Double?) -> SignalStrength {
        guard let value = value else { return .unknown }
        if value >= 0.05 { return .strong }
        if value >= 0.02 { return .moderate }
        if value >= 0 { return .weak }
        return .weak
    }
    
    static func determinePriceAppreciationSignal(_ value: Double?) -> SignalStrength {
        guard let value = value else { return .unknown }
        if value >= 0.05 { return .strong }
        if value >= 0.02 { return .moderate }
        if value >= 0 { return .weak }
        return .weak
    }
    
    static func determineVacancySignal(_ value: Double?) -> SignalStrength {
        guard let value = value else { return .unknown }
        if value <= 0.03 { return .strong }
        if value <= 0.06 { return .moderate }
        if value <= 0.10 { return .weak }
        return .weak
    }
    
    static func determineDOMSignal(_ value: Int?) -> SignalStrength {
        guard let value = value else { return .unknown }
        if value <= 14 { return .strong }
        if value <= 30 { return .moderate }
        if value <= 60 { return .weak }
        return .weak
    }
    
    static func determineSupplySignal(_ value: Double?) -> SignalStrength {
        guard let value = value else { return .unknown }
        if value <= 2 { return .strong }
        if value <= 4 { return .moderate }
        if value <= 6 { return .weak }
        return .weak
    }
    
    static func determineDemandSignal(_ value: Double?) -> SignalStrength {
        guard let value = value else { return .unknown }
        if value >= 0.02 { return .strong }
        if value >= 0.01 { return .moderate }
        if value >= 0 { return .neutral }
        return .weak
    }
}
