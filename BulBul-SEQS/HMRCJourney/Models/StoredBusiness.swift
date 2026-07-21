import Foundation
import SwiftData

@Model
final class StoredBusiness {
    var recordID: UUID = UUID()
    var userID: String = ""
    var nino: String = ""
    var businessID: String = ""
    var typeOfBusiness: String = ""
    var tradingName: String?
    var yearOfMigration: String?
    var firstAccountingPeriodStartDate: String?
    var firstAccountingPeriodEndDate: String?
    var commencementDate: String?
    var cessationDate: String?
    var businessAddressLineOne: String?
    var businessAddressLineTwo: String?
    var businessAddressLineThree: String?
    var businessAddressLineFour: String?
    var businessAddressPostcode: String?
    var businessAddressCountryCode: String?
    var accountingPeriodsData: Data?
    var latencyDetailsData: Data?
    var quarterlyTypeChoiceData: Data?
    var hasDetails: Bool = false
    var fetchedAt: Date?
    var lastErrorCode: String?
    var lastErrorMessage: String?
    var lastErrorStatusCode: Int?
    var lastErrorCorrelationID: String?
    var importedCSVRelativePath: String?
    var obligationsFetchedAt: Date?
    var updatedAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \DigitalRecord.business)
    var digitalRecords: [DigitalRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \StoredObligation.business)
    var obligations: [StoredObligation] = []

    init(userID: String, nino: String, summary: HMRCBusinessSummary) {
        self.userID = userID
        self.nino = nino
        businessID = summary.businessId
        typeOfBusiness = summary.typeOfBusiness
        tradingName = summary.tradingName
    }

    var accountingPeriods: [HMRCAccountingPeriod] {
        decode([HMRCAccountingPeriod].self, from: accountingPeriodsData) ?? []
    }

    var latencyDetails: HMRCLatencyDetails? {
        decode(HMRCLatencyDetails.self, from: latencyDetailsData)
    }

    var quarterlyTypeChoice: HMRCQuarterlyTypeChoice? {
        decode(HMRCQuarterlyTypeChoice.self, from: quarterlyTypeChoiceData)
    }

    var addressLines: [String] {
        [
            businessAddressLineOne,
            businessAddressLineTwo,
            businessAddressLineThree,
            businessAddressLineFour,
            businessAddressPostcode,
            businessAddressCountryCode,
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
    }

    func update(summary: HMRCBusinessSummary) {
        typeOfBusiness = summary.typeOfBusiness
        tradingName = summary.tradingName
        updatedAt = Date()
    }

    func update(details: HMRCBusinessDetails) {
        businessID = details.businessId
        typeOfBusiness = details.typeOfBusiness
        tradingName = details.tradingName
        yearOfMigration = details.yearOfMigration
        firstAccountingPeriodStartDate = details.firstAccountingPeriodStartDate
        firstAccountingPeriodEndDate = details.firstAccountingPeriodEndDate
        commencementDate = details.commencementDate
        cessationDate = details.cessationDate
        businessAddressLineOne = details.businessAddressLineOne
        businessAddressLineTwo = details.businessAddressLineTwo
        businessAddressLineThree = details.businessAddressLineThree
        businessAddressLineFour = details.businessAddressLineFour
        businessAddressPostcode = details.businessAddressPostcode
        businessAddressCountryCode = details.businessAddressCountryCode
        accountingPeriodsData = encode(details.accountingPeriods)
        latencyDetailsData = encode(details.latencyDetails)
        quarterlyTypeChoiceData = encode(details.quarterlyTypeChoice)
        hasDetails = true
        fetchedAt = Date()
        clearError()
        updatedAt = Date()
    }

    func update(error: HMRCAPIError) {
        lastErrorCode = error.code
        lastErrorMessage = error.message
        lastErrorStatusCode = error.statusCode
        lastErrorCorrelationID = error.correlationId
        updatedAt = Date()
    }

    func update(errorMessage: String) {
        lastErrorMessage = errorMessage
        updatedAt = Date()
    }

    private func clearError() {
        lastErrorCode = nil
        lastErrorMessage = nil
        lastErrorStatusCode = nil
        lastErrorCorrelationID = nil
    }

    private func encode<T: Encodable>(_ value: T?) -> Data? {
        guard let value else { return nil }
        return try? JSONEncoder().encode(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
