import Foundation
import SwiftData

@Model
final class DigitalRecord {
    var recordID: UUID = UUID()
    var index: Int = 0
    var date: Date = Date()
    var bankDescription: String = ""
    var amount: Double = 0
    var transactionTypeRawValue: String = DigitalRecordTransactionType.expense.rawValue
    var hmrcCategoryRawValue: String = HMRCCategory.otherExpenses.rawValue
    var classificationConfidence: Double = 0
    var disallowableAmount: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var business: StoredBusiness?

    init(
        index: Int,
        date: Date,
        bankDescription: String,
        amount: Double,
        transactionType: DigitalRecordTransactionType,
        hmrcCategory: HMRCCategory,
        classificationConfidence: Double,
        disallowableAmount: Double,
        business: StoredBusiness? = nil
    ) {
        self.index = index
        self.date = date
        self.bankDescription = bankDescription
        self.amount = amount
        transactionTypeRawValue = transactionType.rawValue
        hmrcCategoryRawValue = hmrcCategory.rawValue
        self.classificationConfidence = min(max(classificationConfidence, 0), 1)
        self.disallowableAmount = min(max(disallowableAmount, 0), abs(amount))
        self.business = business
    }

    var transactionType: DigitalRecordTransactionType {
        get { DigitalRecordTransactionType(rawValue: transactionTypeRawValue) ?? .expense }
        set {
            transactionTypeRawValue = newValue.rawValue
            touch()
        }
    }

    var hmrcCategory: HMRCCategory {
        get { HMRCCategory(rawValue: hmrcCategoryRawValue) ?? .otherExpenses }
        set {
            hmrcCategoryRawValue = newValue.rawValue
            touch()
        }
    }

    func normalizeEditableValues() {
        classificationConfidence = min(max(classificationConfidence, 0), 1)
        disallowableAmount = min(max(disallowableAmount, 0), abs(amount))
        touch()
    }

    func touch() {
        updatedAt = Date()
    }
}

enum DigitalRecordTransactionType: String, CaseIterable, Codable, Identifiable, Sendable {
    case income
    case expense
    case expenseRefund
    case incomeRefund
    case transfer
    case personal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .expenseRefund: "Expense refund"
        case .incomeRefund: "Income refund"
        case .transfer: "Transfer"
        case .personal: "Personal"
        }
    }
}

enum HMRCCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case costOfGoods
    case paymentsToSubcontractors
    case wagesAndStaffCosts
    case carVanTravelExpenses
    case premisesRunningCosts
    case maintenanceCosts
    case adminCosts
    case businessEntertainmentCosts
    case advertisingCosts
    case interestOnBankOtherLoans
    case financeCharges
    case irrecoverableDebts
    case professionalFees
    case depreciation
    case otherExpenses
    case costOfGoodsDisallowable
    case paymentsToSubcontractorsDisallowable
    case wagesAndStaffCostsDisallowable
    case carVanTravelExpensesDisallowable
    case premisesRunningCostsDisallowable
    case maintenanceCostsDisallowable
    case adminCostsDisallowable
    case businessEntertainmentCostsDisallowable
    case advertisingCostsDisallowable
    case interestOnBankOtherLoansDisallowable
    case financeChargesDisallowable
    case irrecoverableDebtsDisallowable
    case professionalFeesDisallowable
    case depreciationDisallowable
    case otherExpensesDisallowable

    var id: String { rawValue }

    static let expenseCategories = Array(allCases.prefix(15))
    static let disallowableCategories = Array(allCases.suffix(15))

    var isDisallowable: Bool { rawValue.hasSuffix("Disallowable") }

    var baseExpense: HMRCCategory {
        guard isDisallowable else { return self }
        let baseValue = String(rawValue.dropLast("Disallowable".count))
        return HMRCCategory(rawValue: baseValue) ?? .otherExpenses
    }

    var disallowableCategory: HMRCCategory {
        if isDisallowable { return self }
        return HMRCCategory(rawValue: rawValue + "Disallowable") ?? .otherExpensesDisallowable
    }

    var title: String {
        rawValue
            .replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }
}
