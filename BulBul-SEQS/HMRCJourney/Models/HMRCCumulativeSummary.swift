import Foundation

struct HMRCObligationDetail: Codable, Hashable, Sendable {
    let periodStartDate: String
    let periodEndDate: String
    let dueDate: String
    let status: String
    let receivedDate: String?
}

struct HMRCBusinessObligations: Codable, Hashable, Sendable {
    let typeOfBusiness: String
    let businessId: String
    let obligationDetails: [HMRCObligationDetail]?
}

struct HMRCIncomeAndExpenditureObligationsResponse: Codable, Sendable {
    let obligations: [HMRCBusinessObligations]?
}

struct HMRCIncomeAndExpenditureObligationsResult: Codable, Sendable {
    let success: Bool
    let data: HMRCIncomeAndExpenditureObligationsResponse?
    let error: HMRCAPIError?
}

struct HMRCCumulativePeriodDates: Codable, Hashable, Sendable {
    let periodStartDate: String
    let periodEndDate: String
}

struct HMRCCumulativeIncome: Codable, Hashable, Sendable {
    let turnover: Double?
    let other: Double?
    let taxTakenOffTradingIncome: Double?
}

struct HMRCCumulativeExpenses: Codable, Hashable, Sendable {
    let costOfGoods: Double?
    let paymentsToSubcontractors: Double?
    let wagesAndStaffCosts: Double?
    let carVanTravelExpenses: Double?
    let premisesRunningCosts: Double?
    let maintenanceCosts: Double?
    let adminCosts: Double?
    let businessEntertainmentCosts: Double?
    let advertisingCosts: Double?
    let interestOnBankOtherLoans: Double?
    let financeCharges: Double?
    let irrecoverableDebts: Double?
    let professionalFees: Double?
    let depreciation: Double?
    let otherExpenses: Double?

    var keyedValues: [String: Double] {
        compactDictionary([
            "costOfGoods": costOfGoods,
            "paymentsToSubcontractors": paymentsToSubcontractors,
            "wagesAndStaffCosts": wagesAndStaffCosts,
            "carVanTravelExpenses": carVanTravelExpenses,
            "premisesRunningCosts": premisesRunningCosts,
            "maintenanceCosts": maintenanceCosts,
            "adminCosts": adminCosts,
            "businessEntertainmentCosts": businessEntertainmentCosts,
            "advertisingCosts": advertisingCosts,
            "interestOnBankOtherLoans": interestOnBankOtherLoans,
            "financeCharges": financeCharges,
            "irrecoverableDebts": irrecoverableDebts,
            "professionalFees": professionalFees,
            "depreciation": depreciation,
            "otherExpenses": otherExpenses,
        ])
    }
}

struct HMRCCumulativeDisallowableExpenses: Codable, Hashable, Sendable {
    let costOfGoodsDisallowable: Double?
    let paymentsToSubcontractorsDisallowable: Double?
    let wagesAndStaffCostsDisallowable: Double?
    let carVanTravelExpensesDisallowable: Double?
    let premisesRunningCostsDisallowable: Double?
    let maintenanceCostsDisallowable: Double?
    let adminCostsDisallowable: Double?
    let businessEntertainmentCostsDisallowable: Double?
    let advertisingCostsDisallowable: Double?
    let interestOnBankOtherLoansDisallowable: Double?
    let financeChargesDisallowable: Double?
    let irrecoverableDebtsDisallowable: Double?
    let professionalFeesDisallowable: Double?
    let depreciationDisallowable: Double?
    let otherExpensesDisallowable: Double?

    var keyedValues: [String: Double] {
        compactDictionary([
            "costOfGoodsDisallowable": costOfGoodsDisallowable,
            "paymentsToSubcontractorsDisallowable": paymentsToSubcontractorsDisallowable,
            "wagesAndStaffCostsDisallowable": wagesAndStaffCostsDisallowable,
            "carVanTravelExpensesDisallowable": carVanTravelExpensesDisallowable,
            "premisesRunningCostsDisallowable": premisesRunningCostsDisallowable,
            "maintenanceCostsDisallowable": maintenanceCostsDisallowable,
            "adminCostsDisallowable": adminCostsDisallowable,
            "businessEntertainmentCostsDisallowable": businessEntertainmentCostsDisallowable,
            "advertisingCostsDisallowable": advertisingCostsDisallowable,
            "interestOnBankOtherLoansDisallowable": interestOnBankOtherLoansDisallowable,
            "financeChargesDisallowable": financeChargesDisallowable,
            "irrecoverableDebtsDisallowable": irrecoverableDebtsDisallowable,
            "professionalFeesDisallowable": professionalFeesDisallowable,
            "depreciationDisallowable": depreciationDisallowable,
            "otherExpensesDisallowable": otherExpensesDisallowable,
        ])
    }
}

struct HMRCConsolidatedExpenses: Codable, Hashable, Sendable {
    let consolidatedExpenses: Double?
}

struct HMRCConsolidatedCumulativeSummary: Codable, Hashable, Sendable {
    let periodDates: HMRCCumulativePeriodDates
    let periodIncome: HMRCCumulativeIncome?
    let periodExpenses: HMRCConsolidatedExpenses?
}

struct HMRCNonConsolidatedCumulativeSummary: Codable, Hashable, Sendable {
    let periodDates: HMRCCumulativePeriodDates
    let periodIncome: HMRCCumulativeIncome?
    let periodExpenses: HMRCCumulativeExpenses?
    let periodDisallowableExpenses: HMRCCumulativeDisallowableExpenses?
}

struct HMRCGetConsolidatedCumulativeSummaryResult: Codable, Sendable {
    let success: Bool
    let data: HMRCConsolidatedCumulativeSummary?
    let error: HMRCAPIError?
}

struct HMRCGetNonConsolidatedCumulativeSummaryResult: Codable, Sendable {
    let success: Bool
    let data: HMRCNonConsolidatedCumulativeSummary?
    let error: HMRCAPIError?
}

struct HMRCPutCumulativeSummaryResponse: Codable, Hashable, Sendable {
    let correlationId: String?
}

struct HMRCPutCumulativeSummaryResult: Codable, Sendable {
    let success: Bool
    let data: HMRCPutCumulativeSummaryResponse?
    let error: HMRCAPIError?
}

struct HMRCCumulativeSummaryDraft: Hashable, Sendable {
    var periodStartDate: String
    var periodEndDate: String
    var turnover: Double
    var otherIncome: Double
    var taxTakenOffTradingIncome: Double
    var expenses: [String: Double]
    var disallowableExpenses: [String: Double]

    var consolidatedExpenses: Double {
        expenses.values.reduce(0, +)
    }

    func consolidatedInput() -> [String: Any] {
        [
            "periodDates": dateInput,
            "periodIncome": incomeInput,
            "periodExpenses": ["consolidatedExpenses": rounded(consolidatedExpenses)],
        ]
    }

    func nonConsolidatedInput() -> [String: Any] {
        [
            "periodDates": dateInput,
            "periodIncome": incomeInput,
            "periodExpenses": roundedDictionary(expenses),
            "periodDisallowableExpenses": roundedDictionary(disallowableExpenses),
        ]
    }

    private var dateInput: [String: Any] {
        ["periodStartDate": periodStartDate, "periodEndDate": periodEndDate]
    }

    private var incomeInput: [String: Any] {
        [
            "turnover": rounded(turnover),
            "other": rounded(otherIncome),
            "taxTakenOffTradingIncome": rounded(taxTakenOffTradingIncome),
        ]
    }
}

enum HMRCCumulativeSummaryCalculator {
    static func calculate(
        records: [DigitalRecord],
        periodStartDate: String,
        periodEndDate: String
    ) -> HMRCCumulativeSummaryDraft {
        let start = HMRCDate.date(from: periodStartDate) ?? .distantPast
        let end = HMRCDate.date(from: periodEndDate) ?? .distantFuture
        let included = records.filter { $0.date >= start && $0.date <= HMRCDate.endOfDay(end) }

        var turnover = 0.0
        var expenses = Dictionary(uniqueKeysWithValues: HMRCCategory.expenseCategories.map { ($0.rawValue, 0.0) })
        var disallowable = Dictionary(uniqueKeysWithValues: HMRCCategory.disallowableCategories.map { ($0.rawValue, 0.0) })

        for record in included {
            switch record.transactionType {
            case .income:
                turnover += abs(record.amount)
            case .incomeRefund:
                turnover -= abs(record.amount)
            case .expense, .expenseRefund:
                let direction = record.transactionType == .expense ? 1.0 : -1.0
                let gross = abs(record.amount)
                let enteredDisallowable = record.hmrcCategory.isDisallowable && record.disallowableAmount == 0
                    ? gross
                    : min(record.disallowableAmount, gross)
                let allowable = max(gross - enteredDisallowable, 0)
                expenses[record.hmrcCategory.baseExpense.rawValue, default: 0] += direction * allowable
                disallowable[record.hmrcCategory.disallowableCategory.rawValue, default: 0] += direction * enteredDisallowable
            case .transfer, .personal:
                break
            }
        }

        return HMRCCumulativeSummaryDraft(
            periodStartDate: periodStartDate,
            periodEndDate: periodEndDate,
            turnover: max(rounded(turnover), 0),
            otherIncome: 0,
            taxTakenOffTradingIncome: 0,
            expenses: expenses.mapValues { max(rounded($0), 0) },
            disallowableExpenses: disallowable.mapValues { max(rounded($0), 0) }
        )
    }
}

enum HMRCDate {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(from value: String) -> Date? { formatter.date(from: value) }
    static func string(from date: Date) -> String { formatter.string(from: date) }

    static func endOfDay(_ date: Date) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: DateComponents(day: 1, second: -1), to: date) ?? date
    }

    static func taxYear(containing dateValue: String) -> String {
        guard let date = date(from: dateValue) else { return "" }
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let startYear = (month > 4 || (month == 4 && day >= 6)) ? year : year - 1
        return String(format: "%04d-%02d", startYear, (startYear + 1) % 100)
    }
}

private func compactDictionary(_ input: [String: Double?]) -> [String: Double] {
    input.reduce(into: [:]) { result, entry in
        if let value = entry.value { result[entry.key] = value }
    }
}

private func roundedDictionary(_ input: [String: Double]) -> [String: Any] {
    input.reduce(into: [String: Any]()) { result, entry in
        result[entry.key] = rounded(entry.value)
    }
}

private func rounded(_ value: Double) -> Double {
    (value * 100).rounded() / 100
}
