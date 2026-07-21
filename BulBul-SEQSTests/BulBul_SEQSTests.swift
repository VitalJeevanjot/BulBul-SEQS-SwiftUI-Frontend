//
//  BulBul_SEQSTests.swift
//  BulBul-SEQSTests
//
//  Created by Jeevanjot Singh on 26/05/26.
//

import Testing
import Foundation
import SwiftData
@testable import BulBul_SEQS

struct BulBul_SEQSTests {

    @Test func ninoValidationMatchesHMRCRestrictions() {
        #expect(HMRCIdentifierValidator.isValidNINO("AB123456C"))
        #expect(!HMRCIdentifierValidator.isValidNINO("BG123456A"))
        #expect(!HMRCIdentifierValidator.isValidNINO("DA123456A"))
        #expect(!HMRCIdentifierValidator.isValidNINO("AO123456A"))
        #expect(!HMRCIdentifierValidator.isValidNINO("AB123456E"))
        #expect(!HMRCIdentifierValidator.isValidNINO("AB12345C"))
    }

    @Test func ninoInputIsNormalizedBeforeValidation() {
        #expect(HMRCIdentifierValidator.normalizedNINO("ab 12-34 56 c") == "AB123456C")
    }

    @Test func businessIDValidationMatchesRequiredFormat() {
        #expect(HMRCIdentifierValidator.isValidBusinessID("XAIS12345678901"))
        #expect(HMRCIdentifierValidator.isValidBusinessID("X7IS12345678901"))
        #expect(!HMRCIdentifierValidator.isValidBusinessID("AAIS12345678901"))
        #expect(!HMRCIdentifierValidator.isValidBusinessID("XAIS1234567890"))
        #expect(!HMRCIdentifierValidator.isValidBusinessID("XAIS123456789012"))
    }

    @Test func oauthErrorCallbackProducesPromptError() throws {
        let callbackURL = try #require(
            URL(
                string:
                    "bulbulseqs://oauth/callback?error=access_denied&error_code=TEST-403&error_description=User%20cancelled"
            )
        )

        do {
            _ = try HMRCAuthCallback.authorizationCode(
                from: callbackURL,
                expectedState: "expected-state"
            )
            Issue.record("Expected the OAuth callback to throw an error.")
        } catch let error as HMRCAuthPromptError {
            #expect(error.code == "BulBul-Seqs-1F")
            #expect(error.description.contains("access_denied"))
            #expect(error.description.contains("TEST-403"))
            #expect(error.description.contains("User cancelled"))
        }
    }

    @Test func validOAuthCallbackReturnsAuthorizationCode() throws {
        let callbackURL = try #require(
            URL(
                string:
                    "bulbulseqs://oauth/callback?code=test-code&state=expected-state"
            )
        )

        let code = try HMRCAuthCallback.authorizationCode(
            from: callbackURL,
            expectedState: "expected-state"
        )

        #expect(code == "test-code")
    }

    @Test func mismatchedOAuthStateIsRejected() throws {
        let callbackURL = try #require(
            URL(
                string:
                    "bulbulseqs://oauth/callback?code=test-code&state=wrong-state"
            )
        )

        do {
            _ = try HMRCAuthCallback.authorizationCode(
                from: callbackURL,
                expectedState: "expected-state"
            )
            Issue.record("Expected a mismatched OAuth state to be rejected.")
        } catch let error as HMRCAuthPromptError {
            #expect(error.code == "BulBul-Seqs-1H")
        }
    }

    @Test func hmrcTokenStatusResponseDecodes() throws {
        let json = Data(
            """
            {
              "success": true,
              "data": {
                "isSignedInWithHmrc": true
              },
              "error": null
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(HMRCTokenStatusResult.self, from: json)

        #expect(response.success)
        #expect(response.data?.isSignedInWithHmrc == true)
    }

    @Test func hmrcOAuthStructuredErrorDecodes() throws {
        let json = Data(
            """
            {
              "success": false,
              "token": null,
              "error": {
                "statusCode": 401,
                "error": "invalid_grant",
                "errorDescription": "The HMRC session has expired."
              }
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(HMRCOAuthTokenResult.self, from: json)

        #expect(!response.success)
        #expect(response.error?.error == "invalid_grant")
        #expect(response.error?.description == "The HMRC session has expired.")
    }

    @Test @MainActor func deletingLocalUserDataRemovesProfilesAndBusinesses() throws {
        let schema = Schema([
            HMRCUserProfile.self,
            StoredBusiness.self,
            DigitalRecord.self,
            StoredObligation.self,
        ])
        let configuration = ModelConfiguration(
            "HMRCBusinessStore",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let modelContext = container.mainContext

        modelContext.insert(
            HMRCUserProfile(
                userID: "test-user",
                email: "user@example.com",
                nino: "AB123456C"
            )
        )
        modelContext.insert(
            StoredBusiness(
                userID: "test-user",
                nino: "AB123456C",
                summary: HMRCBusinessSummary(
                    typeOfBusiness: "self-employment",
                    businessId: "XAIS12345678901",
                    tradingName: "Test Business"
                )
            )
        )
        try modelContext.save()

        try LocalUserDataStore.deleteAll(from: modelContext)

        #expect(try modelContext.fetchCount(FetchDescriptor<HMRCUserProfile>()) == 0)
        #expect(try modelContext.fetchCount(FetchDescriptor<StoredBusiness>()) == 0)
        #expect(try modelContext.fetchCount(FetchDescriptor<DigitalRecord>()) == 0)
        #expect(try modelContext.fetchCount(FetchDescriptor<StoredObligation>()) == 0)
    }

    @Test @MainActor func gettingBusinessesReplacesOlderBusinessesAndTheirData() async throws {
        let schema = Schema([
            HMRCUserProfile.self,
            StoredBusiness.self,
            DigitalRecord.self,
            StoredObligation.self,
        ])
        let configuration = ModelConfiguration(
            "HMRCBusinessRefreshStore",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let modelContext = container.mainContext
        let profile = HMRCUserProfile(
            userID: "test-user",
            email: "user@example.com",
            nino: "AB123456C"
        )
        let olderBusiness = StoredBusiness(
            userID: profile.userID,
            nino: "AB123456C",
            summary: HMRCBusinessSummary(
                typeOfBusiness: "self-employment",
                businessId: "XAIS12345678901",
                tradingName: "Older Business"
            )
        )
        let olderRecord = DigitalRecord(
            index: 1,
            date: Date(),
            bankDescription: "Older transaction",
            amount: 100,
            transactionType: .income,
            hmrcCategory: .otherExpenses,
            classificationConfidence: 1,
            disallowableAmount: 0,
            business: olderBusiness
        )
        let olderObligation = StoredObligation(
            typeOfBusiness: "self-employment",
            businessID: olderBusiness.businessID,
            detail: HMRCObligationDetail(
                periodStartDate: "2025-04-06",
                periodEndDate: "2025-07-05",
                dueDate: "2025-08-07",
                status: "Open",
                receivedDate: nil
            ),
            business: olderBusiness
        )

        modelContext.insert(profile)
        modelContext.insert(olderBusiness)
        modelContext.insert(olderRecord)
        modelContext.insert(olderObligation)
        try modelContext.save()

        let viewModel = HMRCJourneyViewModel(api: ReplacingBusinessesAPI())
        viewModel.profile = profile
        viewModel.ninoInput = "AB123456C"

        await viewModel.getBusinesses(modelContext: modelContext)

        let storedBusinesses = try modelContext.fetch(FetchDescriptor<StoredBusiness>())
        #expect(viewModel.issues.isEmpty, "\(viewModel.issues.map { $0.message })")
        #expect(storedBusinesses.map(\.businessID) == ["XAIS12345678902"])
        #expect(viewModel.businesses.map(\.businessID) == ["XAIS12345678902"])
        #expect(try modelContext.fetchCount(FetchDescriptor<DigitalRecord>()) == 0)
        #expect(try modelContext.fetchCount(FetchDescriptor<StoredObligation>()) == 0)
        #expect(try modelContext.fetchCount(FetchDescriptor<HMRCUserProfile>()) == 1)
    }

    @Test func cumulativeCategoriesContainAllThirtyAmplifyKeys() {
        #expect(HMRCCategory.expenseCategories.count == 15)
        #expect(HMRCCategory.disallowableCategories.count == 15)
        #expect(Set(HMRCCategory.allCases.map(\.rawValue)).count == 30)
        #expect(HMRCCategory.costOfGoods.disallowableCategory == .costOfGoodsDisallowable)
        #expect(HMRCCategory.professionalFeesDisallowable.baseExpense == .professionalFees)
    }

    @Test func obligationPeriodProducesHMRCtaxYear() {
        #expect(HMRCDate.taxYear(containing: "2025-04-05") == "2024-25")
        #expect(HMRCDate.taxYear(containing: "2025-04-06") == "2025-26")
        #expect(HMRCDate.taxYear(containing: "2026-03-31") == "2025-26")
    }

    @Test @MainActor func cumulativeCalculationUsesOnlyObligationPeriodAndBusinessTransactions() throws {
        let expenseDate = try #require(HMRCDate.date(from: "2025-06-01"))
        let outsideDate = try #require(HMRCDate.date(from: "2026-05-01"))
        let records = [
            DigitalRecord(
                index: 1,
                date: expenseDate,
                bankDescription: "Customer payment",
                amount: 1_000,
                transactionType: .income,
                hmrcCategory: .otherExpenses,
                classificationConfidence: 0.9,
                disallowableAmount: 0
            ),
            DigitalRecord(
                index: 2,
                date: expenseDate,
                bankDescription: "Vehicle costs",
                amount: -200,
                transactionType: .expense,
                hmrcCategory: .carVanTravelExpenses,
                classificationConfidence: 0.9,
                disallowableAmount: 50
            ),
            DigitalRecord(
                index: 3,
                date: outsideDate,
                bankDescription: "Outside period",
                amount: 9_999,
                transactionType: .income,
                hmrcCategory: .otherExpenses,
                classificationConfidence: 0.9,
                disallowableAmount: 0
            ),
        ]

        let draft = HMRCCumulativeSummaryCalculator.calculate(
            records: records,
            periodStartDate: "2025-04-06",
            periodEndDate: "2026-04-05"
        )
        #expect(draft.turnover == 1_000)
        #expect(draft.expenses[HMRCCategory.carVanTravelExpenses.rawValue] == 150)
        #expect(draft.disallowableExpenses[HMRCCategory.carVanTravelExpensesDisallowable.rawValue] == 50)
        #expect(draft.consolidatedExpenses == 150)
    }

    @Test func obligationsResponseDecodes() throws {
        let json = Data(
            """
            {"success":true,"data":{"obligations":[{"typeOfBusiness":"self-employment","businessId":"XAIS12345678901","obligationDetails":[{"periodStartDate":"2025-04-06","periodEndDate":"2025-07-05","dueDate":"2025-08-07","status":"Open","receivedDate":null}]}]},"error":null}
            """.utf8
        )
        let result = try JSONDecoder().decode(HMRCIncomeAndExpenditureObligationsResult.self, from: json)
        #expect(result.success)
        #expect(result.data?.obligations?.first?.obligationDetails?.first?.status == "Open")
    }

    @Test @MainActor func sampleCSVContainsOneHundredValidRecords() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sampleURL = repositoryRoot.appending(path: "BulBul-SEQS/Samples/SampleDigitalRecords.csv")
        let contents = try String(contentsOf: sampleURL, encoding: .utf8)
        let records = try DigitalRecordCSVStore.records(fromCSV: contents)

        #expect(records.count == 100)
        #expect(records.map(\.index) == Array(1...100))
        #expect(Set(records.map(\.transactionType)).count == DigitalRecordTransactionType.allCases.count)
        #expect(records.allSatisfy { $0.disallowableAmount >= 0 && $0.disallowableAmount <= abs($0.amount) })
    }

    @Test @MainActor func digitalRecordCSVExportRoundTripsEditedValues() throws {
        let date = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 7,
            day: 22
        ).date!
        let source = DigitalRecord(
            index: 7,
            date: date,
            bankDescription: "Client, \"priority\" invoice",
            amount: 1_234.5,
            transactionType: .income,
            hmrcCategory: .otherExpenses,
            classificationConfidence: 0.93,
            disallowableAmount: 0
        )

        let contents = DigitalRecordCSVStore.csv(from: [source])
        let exported = try #require(DigitalRecordCSVStore.records(fromCSV: contents).first)

        #expect(contents.contains("\"Client, \"\"priority\"\" invoice\""))
        #expect(exported.index == source.index)
        #expect(exported.date == source.date)
        #expect(exported.bankDescription == source.bankDescription)
        #expect(exported.amount == source.amount)
        #expect(exported.transactionType == source.transactionType)
        #expect(exported.hmrcCategory == source.hmrcCategory)
        #expect(exported.classificationConfidence == source.classificationConfidence)
        #expect(exported.disallowableAmount == source.disallowableAmount)
    }

}

private struct ReplacingBusinessesAPI: HMRCBusinessAPIProtocol {
    func getTokenStatus() async throws -> HMRCTokenStatusResult {
        fatalError("Not needed by this test")
    }

    func refreshAccessToken() async throws -> HMRCOAuthTokenResult {
        fatalError("Not needed by this test")
    }

    func listBusinesses(nino: String) async throws -> HMRCListBusinessesResult {
        HMRCListBusinessesResult(
            success: true,
            data: HMRCListBusinessesResponse(
                listOfBusinesses: [
                    HMRCBusinessSummary(
                        typeOfBusiness: "self-employment",
                        businessId: "XAIS12345678902",
                        tradingName: "Replacement Business"
                    )
                ]
            ),
            error: nil
        )
    }

    func retrieveBusinessDetails(
        nino: String,
        businessID: String
    ) async throws -> HMRCRetrieveBusinessDetailsResult {
        HMRCRetrieveBusinessDetailsResult(
            success: true,
            data: HMRCBusinessDetails(
                businessId: businessID,
                typeOfBusiness: "self-employment",
                tradingName: "Replacement Business",
                yearOfMigration: nil,
                firstAccountingPeriodStartDate: nil,
                firstAccountingPeriodEndDate: nil,
                latencyDetails: nil,
                quarterlyTypeChoice: nil,
                accountingPeriods: nil,
                commencementDate: nil,
                cessationDate: nil,
                businessAddressLineOne: nil,
                businessAddressLineTwo: nil,
                businessAddressLineThree: nil,
                businessAddressLineFour: nil,
                businessAddressPostcode: nil,
                businessAddressCountryCode: nil
            ),
            error: nil
        )
    }

    func retrieveIncomeAndExpenditureObligations(
        nino: String,
        typeOfBusiness: String?,
        businessID: String?,
        fromDate: String?,
        toDate: String?,
        status: String?
    ) async throws -> HMRCIncomeAndExpenditureObligationsResult {
        HMRCIncomeAndExpenditureObligationsResult(
            success: true,
            data: HMRCIncomeAndExpenditureObligationsResponse(obligations: []),
            error: nil
        )
    }

    func getSelfEmploymentCumulativeSummaryConsolidated(
        nino: String,
        businessID: String,
        taxYear: String
    ) async throws -> HMRCGetConsolidatedCumulativeSummaryResult {
        fatalError("Not needed by this test")
    }

    func getSelfEmploymentCumulativeSummaryNonConsolidated(
        nino: String,
        businessID: String,
        taxYear: String
    ) async throws -> HMRCGetNonConsolidatedCumulativeSummaryResult {
        fatalError("Not needed by this test")
    }

    func putSelfEmploymentCumulativeSummaryConsolidated(
        nino: String,
        businessID: String,
        taxYear: String,
        summary: [String: Any]
    ) async throws -> HMRCPutCumulativeSummaryResult {
        fatalError("Not needed by this test")
    }

    func putSelfEmploymentCumulativeSummaryNonConsolidated(
        nino: String,
        businessID: String,
        taxYear: String,
        summary: [String: Any]
    ) async throws -> HMRCPutCumulativeSummaryResult {
        fatalError("Not needed by this test")
    }

    func createTestBusiness(
        nino: String,
        business: HMRCCreateTestBusinessPayload
    ) async throws -> HMRCCreateTestBusinessResult {
        fatalError("Not needed by this test")
    }
}
