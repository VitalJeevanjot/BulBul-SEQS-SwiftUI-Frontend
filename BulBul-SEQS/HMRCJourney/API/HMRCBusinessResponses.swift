import Foundation

struct HMRCAPIError: Codable, Error, Identifiable, Hashable, LocalizedError, Sendable {
    let statusCode: Int
    let code: String
    let message: String
    let correlationId: String?

    var id: String {
        "\(statusCode)-\(code)-\(correlationId ?? message)"
    }

    var errorDescription: String? {
        message
    }
}

struct HMRCTokenStatus: Codable, Hashable, Sendable {
    let isSignedInWithHmrc: Bool
}

struct HMRCTokenStatusResult: Codable, Sendable {
    let success: Bool
    let data: HMRCTokenStatus?
    let error: HMRCAPIError?
}

struct HMRCOAuthTokenMetadata: Codable, Hashable, Sendable {
    let tokenType: String
    let expiresIn: Int
    let expiresAt: String
    let scope: String?
}

struct HMRCOAuthError: Codable, Error, Hashable, LocalizedError, Sendable {
    let statusCode: Int
    let error: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case statusCode
        case error
        case description = "errorDescription"
    }

    var errorDescription: String? {
        description
    }
}

struct HMRCOAuthTokenResult: Codable, Sendable {
    let success: Bool
    let token: HMRCOAuthTokenMetadata?
    let error: HMRCOAuthError?
}

struct HMRCBusinessSummary: Codable, Hashable, Identifiable, Sendable {
    let typeOfBusiness: String
    let businessId: String
    let tradingName: String?

    var id: String { businessId }
}

struct HMRCListBusinessesResponse: Codable, Sendable {
    let listOfBusinesses: [HMRCBusinessSummary]?
}

struct HMRCListBusinessesResult: Codable, Sendable {
    let success: Bool
    let data: HMRCListBusinessesResponse?
    let error: HMRCAPIError?
}

struct HMRCAccountingPeriod: Codable, Hashable, Identifiable, Sendable {
    let start: String
    let end: String

    var id: String { "\(start)-\(end)" }
}

struct HMRCLatencyDetails: Codable, Hashable, Sendable {
    let latencyEndDate: String
    let taxYear1: String
    let latencyIndicator1: String
    let taxYear2: String
    let latencyIndicator2: String
}

struct HMRCQuarterlyTypeChoice: Codable, Hashable, Sendable {
    let quarterlyPeriodType: String?
    let taxYearOfChoice: String?
}

struct HMRCBusinessDetails: Codable, Hashable, Identifiable, Sendable {
    let businessId: String
    let typeOfBusiness: String
    let tradingName: String?
    let yearOfMigration: String?
    let firstAccountingPeriodStartDate: String?
    let firstAccountingPeriodEndDate: String?
    let latencyDetails: HMRCLatencyDetails?
    let quarterlyTypeChoice: HMRCQuarterlyTypeChoice?
    let accountingPeriods: [HMRCAccountingPeriod]?
    let commencementDate: String?
    let cessationDate: String?
    let businessAddressLineOne: String?
    let businessAddressLineTwo: String?
    let businessAddressLineThree: String?
    let businessAddressLineFour: String?
    let businessAddressPostcode: String?
    let businessAddressCountryCode: String?

    var id: String { businessId }
}

struct HMRCRetrieveBusinessDetailsResult: Codable, Sendable {
    let success: Bool
    let data: HMRCBusinessDetails?
    let error: HMRCAPIError?
}

struct HMRCCreateTestBusinessResponse: Codable, Hashable, Sendable {
    let businessId: String
}

struct HMRCCreateTestBusinessResult: Codable, Sendable {
    let success: Bool
    let data: HMRCCreateTestBusinessResponse?
    let error: HMRCAPIError?
}

struct HMRCCreateTestBusinessPayload: Hashable, Sendable {
    var typeOfBusiness: String = "self-employment"
    var tradingName: String?
    var firstAccountingPeriodStartDate: String?
    var firstAccountingPeriodEndDate: String?
    var accountingType: String?
    var commencementDate: String?
    var cessationDate: String?
    var businessAddressLineOne: String?
    var businessAddressLineTwo: String?
    var businessAddressLineThree: String?
    var businessAddressLineFour: String?
    var businessAddressPostcode: String?
    var businessAddressCountryCode: String?
    var quarterlyPeriodType: String?
    var taxYearOfChoice: String?
    var latencyEndDate: String?
    var latencyTaxYear1: String?
    var latencyIndicator1: String?
    var latencyTaxYear2: String?
    var latencyIndicator2: String?

    var graphQLInput: [String: Any] {
        var input: [String: Any] = ["typeOfBusiness": typeOfBusiness]
        input.addNonEmpty(tradingName, for: "tradingName")
        input.addNonEmpty(firstAccountingPeriodStartDate, for: "firstAccountingPeriodStartDate")
        input.addNonEmpty(firstAccountingPeriodEndDate, for: "firstAccountingPeriodEndDate")
        input.addNonEmpty(accountingType, for: "accountingType")
        input.addNonEmpty(commencementDate, for: "commencementDate")
        input.addNonEmpty(cessationDate, for: "cessationDate")
        input.addNonEmpty(businessAddressLineOne, for: "businessAddressLineOne")
        input.addNonEmpty(businessAddressLineTwo, for: "businessAddressLineTwo")
        input.addNonEmpty(businessAddressLineThree, for: "businessAddressLineThree")
        input.addNonEmpty(businessAddressLineFour, for: "businessAddressLineFour")
        input.addNonEmpty(businessAddressPostcode, for: "businessAddressPostcode")
        input.addNonEmpty(businessAddressCountryCode, for: "businessAddressCountryCode")
        if let quarterlyPeriodType, !quarterlyPeriodType.isEmpty,
           let taxYearOfChoice, !taxYearOfChoice.isEmpty {
            input["quarterlyTypeChoice"] = [
                "quarterlyPeriodType": quarterlyPeriodType,
                "taxYearOfChoice": taxYearOfChoice,
            ]
        }
        if let latencyEndDate, !latencyEndDate.isEmpty,
           let latencyTaxYear1, !latencyTaxYear1.isEmpty,
           let latencyIndicator1, !latencyIndicator1.isEmpty,
           let latencyTaxYear2, !latencyTaxYear2.isEmpty,
           let latencyIndicator2, !latencyIndicator2.isEmpty {
            input["latencyDetails"] = [
                "latencyEndDate": latencyEndDate,
                "taxYear1": latencyTaxYear1,
                "latencyIndicator1": latencyIndicator1,
                "taxYear2": latencyTaxYear2,
                "latencyIndicator2": latencyIndicator2,
            ]
        }
        return input
    }
}

private extension Dictionary where Key == String, Value == Any {
    mutating func addNonEmpty(_ value: String?, for key: String) {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self[key] = value
        }
    }
}

struct HMRCJourneyIssue: Identifiable, Hashable, Sendable {
    let id = UUID()
    let title: String
    let message: String
    let code: String?
    let statusCode: Int?
    let correlationID: String?

    init(title: String, message: String, code: String? = nil, statusCode: Int? = nil, correlationID: String? = nil) {
        self.title = title
        self.message = message
        self.code = code
        self.statusCode = statusCode
        self.correlationID = correlationID
    }

    init(title: String, apiError: HMRCAPIError) {
        self.init(
            title: title,
            message: apiError.message,
            code: apiError.code,
            statusCode: apiError.statusCode,
            correlationID: apiError.correlationId
        )
    }
}
