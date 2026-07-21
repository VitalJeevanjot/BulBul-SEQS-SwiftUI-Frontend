import Amplify
import Foundation

protocol HMRCBusinessAPIProtocol: Sendable {
    func getTokenStatus() async throws -> HMRCTokenStatusResult
    func refreshAccessToken() async throws -> HMRCOAuthTokenResult
    func listBusinesses(nino: String) async throws -> HMRCListBusinessesResult
    func retrieveBusinessDetails(nino: String, businessID: String) async throws -> HMRCRetrieveBusinessDetailsResult
    func retrieveIncomeAndExpenditureObligations(
        nino: String,
        typeOfBusiness: String?,
        businessID: String?,
        fromDate: String?,
        toDate: String?,
        status: String?
    ) async throws -> HMRCIncomeAndExpenditureObligationsResult
    func getSelfEmploymentCumulativeSummaryConsolidated(
        nino: String,
        businessID: String,
        taxYear: String
    ) async throws -> HMRCGetConsolidatedCumulativeSummaryResult
    func getSelfEmploymentCumulativeSummaryNonConsolidated(
        nino: String,
        businessID: String,
        taxYear: String
    ) async throws -> HMRCGetNonConsolidatedCumulativeSummaryResult
    func putSelfEmploymentCumulativeSummaryConsolidated(
        nino: String,
        businessID: String,
        taxYear: String,
        summary: [String: Any]
    ) async throws -> HMRCPutCumulativeSummaryResult
    func putSelfEmploymentCumulativeSummaryNonConsolidated(
        nino: String,
        businessID: String,
        taxYear: String,
        summary: [String: Any]
    ) async throws -> HMRCPutCumulativeSummaryResult
    func createTestBusiness(
        nino: String,
        business: HMRCCreateTestBusinessPayload
    ) async throws -> HMRCCreateTestBusinessResult
}

struct HMRCBusinessAPI: HMRCBusinessAPIProtocol {
    func getTokenStatus() async throws -> HMRCTokenStatusResult {
        let request = GraphQLRequest<HMRCTokenStatusResult>(
            document: """
            query GetHmrcTokenStatus {
                getHmrcTokenStatus {
                    success
                    data { isSignedInWithHmrc }
                    error { statusCode code message correlationId }
                }
            }
            """,
            responseType: HMRCTokenStatusResult.self,
            decodePath: "getHmrcTokenStatus"
        )
        return try await query(request)
    }

    func refreshAccessToken() async throws -> HMRCOAuthTokenResult {
        let request = GraphQLRequest<HMRCOAuthTokenResult>(
            document: """
            mutation RefreshAccessToken {
                refreshAccessToken {
                    success
                    token { tokenType expiresIn expiresAt scope }
                    error { statusCode error errorDescription }
                }
            }
            """,
            responseType: HMRCOAuthTokenResult.self,
            decodePath: "refreshAccessToken"
        )
        return try await mutate(request)
    }

    func listBusinesses(nino: String) async throws -> HMRCListBusinessesResult {
        let headers = try await FraudPreventionHeaders.serializedForCurrentRequest()
        let variables: [String: Any] = [
            "nino": nino,
            "fraudPreventionHeaders": headers,
        ]
        let request = GraphQLRequest<HMRCListBusinessesResult>(
            document: """
            query ListBusinesses($nino: String!, $fraudPreventionHeaders: String) {
                listBusinesses(
                    nino: $nino, fraudPreventionHeaders: $fraudPreventionHeaders
                ) {
                    success
                    data { listOfBusinesses { typeOfBusiness businessId tradingName } }
                    error { statusCode code message correlationId }
                }
            }
            """,
            variables: variables,
            responseType: HMRCListBusinessesResult.self,
            decodePath: "listBusinesses"
        )
        let response = try await query(request)
        print("[HMRC] listBusinesses response: \(String(reflecting: response))")
        return response
    }

    func retrieveBusinessDetails(
        nino: String,
        businessID: String
    ) async throws -> HMRCRetrieveBusinessDetailsResult {
        let headers = try await FraudPreventionHeaders.serializedForCurrentRequest()
        let variables: [String: Any] = [
            "nino": nino,
            "businessId": businessID,
            "fraudPreventionHeaders": headers,
        ]
        let request = GraphQLRequest<HMRCRetrieveBusinessDetailsResult>(
            document: """
            query RetrieveBusinessDetails(
                $nino: String!, $businessId: String!, $fraudPreventionHeaders: String
            ) {
                retrieveBusinessDetails(
                    nino: $nino, businessId: $businessId,
                    fraudPreventionHeaders: $fraudPreventionHeaders
                ) {
                    success
                    data {
                        businessId typeOfBusiness tradingName yearOfMigration
                        firstAccountingPeriodStartDate firstAccountingPeriodEndDate
                        latencyDetails { latencyEndDate taxYear1 latencyIndicator1 taxYear2 latencyIndicator2 }
                        quarterlyTypeChoice { quarterlyPeriodType taxYearOfChoice }
                        accountingPeriods { start end }
                        commencementDate cessationDate
                        businessAddressLineOne businessAddressLineTwo businessAddressLineThree
                        businessAddressLineFour businessAddressPostcode businessAddressCountryCode
                    }
                    error { statusCode code message correlationId }
                }
            }
            """,
            variables: variables,
            responseType: HMRCRetrieveBusinessDetailsResult.self,
            decodePath: "retrieveBusinessDetails"
        )
        let response = try await query(request)
        print("[HMRC] retrieveBusinessDetails(\(businessID)) response: \(String(reflecting: response))")
        return response
    }

    func retrieveIncomeAndExpenditureObligations(
        nino: String,
        typeOfBusiness: String? = nil,
        businessID: String? = nil,
        fromDate: String? = nil,
        toDate: String? = nil,
        status: String? = nil
    ) async throws -> HMRCIncomeAndExpenditureObligationsResult {
        let headers = try await FraudPreventionHeaders.serializedForCurrentRequest()
        var variables: [String: Any] = [
            "nino": nino,
            "fraudPreventionHeaders": headers,
        ]
        variables.add(typeOfBusiness, for: "typeOfBusiness")
        variables.add(businessID, for: "businessId")
        variables.add(fromDate, for: "fromDate")
        variables.add(toDate, for: "toDate")
        variables.add(status, for: "status")

        let request = GraphQLRequest<HMRCIncomeAndExpenditureObligationsResult>(
            document: """
            query RetrieveIncomeAndExpenditureObligations(
                $nino: String!, $typeOfBusiness: String, $businessId: String,
                $fromDate: AWSDate, $toDate: AWSDate, $status: String,
                $fraudPreventionHeaders: String
            ) {
                retrieveIncomeAndExpenditureObligations(
                    nino: $nino, typeOfBusiness: $typeOfBusiness, businessId: $businessId,
                    fromDate: $fromDate, toDate: $toDate, status: $status,
                    fraudPreventionHeaders: $fraudPreventionHeaders
                ) {
                    success
                    data {
                        obligations {
                            typeOfBusiness businessId
                            obligationDetails { periodStartDate periodEndDate dueDate status receivedDate }
                        }
                    }
                    error { statusCode code message correlationId }
                }
            }
            """,
            variables: variables,
            responseType: HMRCIncomeAndExpenditureObligationsResult.self,
            decodePath: "retrieveIncomeAndExpenditureObligations"
        )
        return try await query(request)
    }

    func getSelfEmploymentCumulativeSummaryConsolidated(
        nino: String,
        businessID: String,
        taxYear: String
    ) async throws -> HMRCGetConsolidatedCumulativeSummaryResult {
        let headers = try await FraudPreventionHeaders.serializedForCurrentRequest()
        let request = GraphQLRequest<HMRCGetConsolidatedCumulativeSummaryResult>(
            document: """
            query GetSelfEmploymentCumulativeSummaryConsolidated(
                $nino: String!, $businessId: String!, $taxYear: String!, $fraudPreventionHeaders: String
            ) {
                getSelfEmploymentCumulativeSummaryConsolidated(
                    nino: $nino, businessId: $businessId, taxYear: $taxYear,
                    fraudPreventionHeaders: $fraudPreventionHeaders
                ) {
                    success
                    data {
                        periodDates { periodStartDate periodEndDate }
                        periodIncome { turnover other taxTakenOffTradingIncome }
                        periodExpenses { consolidatedExpenses }
                    }
                    error { statusCode code message correlationId }
                }
            }
            """,
            variables: baseSummaryVariables(nino: nino, businessID: businessID, taxYear: taxYear, headers: headers),
            responseType: HMRCGetConsolidatedCumulativeSummaryResult.self,
            decodePath: "getSelfEmploymentCumulativeSummaryConsolidated"
        )
        return try await query(request)
    }

    func getSelfEmploymentCumulativeSummaryNonConsolidated(
        nino: String,
        businessID: String,
        taxYear: String
    ) async throws -> HMRCGetNonConsolidatedCumulativeSummaryResult {
        let headers = try await FraudPreventionHeaders.serializedForCurrentRequest()
        let request = GraphQLRequest<HMRCGetNonConsolidatedCumulativeSummaryResult>(
            document: """
            query GetSelfEmploymentCumulativeSummaryNonConsolidated(
                $nino: String!, $businessId: String!, $taxYear: String!, $fraudPreventionHeaders: String
            ) {
                getSelfEmploymentCumulativeSummaryNonConsolidated(
                    nino: $nino, businessId: $businessId, taxYear: $taxYear,
                    fraudPreventionHeaders: $fraudPreventionHeaders
                ) {
                    success
                    data {
                        periodDates { periodStartDate periodEndDate }
                        periodIncome { turnover other taxTakenOffTradingIncome }
                        periodExpenses {
                            costOfGoods paymentsToSubcontractors wagesAndStaffCosts carVanTravelExpenses
                            premisesRunningCosts maintenanceCosts adminCosts businessEntertainmentCosts
                            advertisingCosts interestOnBankOtherLoans financeCharges irrecoverableDebts
                            professionalFees depreciation otherExpenses
                        }
                        periodDisallowableExpenses {
                            costOfGoodsDisallowable paymentsToSubcontractorsDisallowable wagesAndStaffCostsDisallowable
                            carVanTravelExpensesDisallowable premisesRunningCostsDisallowable maintenanceCostsDisallowable
                            adminCostsDisallowable businessEntertainmentCostsDisallowable advertisingCostsDisallowable
                            interestOnBankOtherLoansDisallowable financeChargesDisallowable irrecoverableDebtsDisallowable
                            professionalFeesDisallowable depreciationDisallowable otherExpensesDisallowable
                        }
                    }
                    error { statusCode code message correlationId }
                }
            }
            """,
            variables: baseSummaryVariables(nino: nino, businessID: businessID, taxYear: taxYear, headers: headers),
            responseType: HMRCGetNonConsolidatedCumulativeSummaryResult.self,
            decodePath: "getSelfEmploymentCumulativeSummaryNonConsolidated"
        )
        return try await query(request)
    }

    func putSelfEmploymentCumulativeSummaryConsolidated(
        nino: String,
        businessID: String,
        taxYear: String,
        summary: [String: Any]
    ) async throws -> HMRCPutCumulativeSummaryResult {
        try await putCumulativeSummary(
            operation: "putSelfEmploymentCumulativeSummaryConsolidated",
            inputType: "ConsolidatedCumulativePeriodSummaryPayloadInput",
            nino: nino,
            businessID: businessID,
            taxYear: taxYear,
            summary: summary
        )
    }

    func putSelfEmploymentCumulativeSummaryNonConsolidated(
        nino: String,
        businessID: String,
        taxYear: String,
        summary: [String: Any]
    ) async throws -> HMRCPutCumulativeSummaryResult {
        try await putCumulativeSummary(
            operation: "putSelfEmploymentCumulativeSummaryNonConsolidated",
            inputType: "NonConsolidatedCumulativePeriodSummaryPayloadInput",
            nino: nino,
            businessID: businessID,
            taxYear: taxYear,
            summary: summary
        )
    }

    func createTestBusiness(
        nino: String,
        business: HMRCCreateTestBusinessPayload
    ) async throws -> HMRCCreateTestBusinessResult {
        let request = GraphQLRequest<HMRCCreateTestBusinessResult>(
            document: """
            mutation CreateTestBusiness($nino: String!, $business: CreateTestBusinessPayloadInput!) {
                createTestBusiness(nino: $nino, business: $business) {
                    success
                    data { businessId }
                    error { statusCode code message correlationId }
                }
            }
            """,
            variables: ["nino": nino, "business": business.graphQLInput],
            responseType: HMRCCreateTestBusinessResult.self,
            decodePath: "createTestBusiness"
        )
        return try await mutate(request)
    }

    private func putCumulativeSummary(
        operation: String,
        inputType: String,
        nino: String,
        businessID: String,
        taxYear: String,
        summary: [String: Any]
    ) async throws -> HMRCPutCumulativeSummaryResult {
        let headers = try await FraudPreventionHeaders.serializedForCurrentRequest()
        let variables: [String: Any] = [
            "nino": nino,
            "businessId": businessID,
            "taxYear": taxYear,
            "summary": summary,
            "fraudPreventionHeaders": headers,
        ]

        let request = GraphQLRequest<HMRCPutCumulativeSummaryResult>(
            document: """
            mutation PutSummary(
                $nino: String!, $businessId: String!, $taxYear: String!,
                $summary: \(inputType)!, $fraudPreventionHeaders: String
            ) {
                \(operation)(
                    nino: $nino, businessId: $businessId, taxYear: $taxYear,
                    summary: $summary, fraudPreventionHeaders: $fraudPreventionHeaders
                ) {
                    success
                    data { correlationId }
                    error { statusCode code message correlationId }
                }
            }
            """,
            variables: variables,
            responseType: HMRCPutCumulativeSummaryResult.self,
            decodePath: operation
        )
        return try await mutate(request)
    }

    private func baseSummaryVariables(
        nino: String,
        businessID: String,
        taxYear: String,
        headers: String
    ) -> [String: Any] {
        [
            "nino": nino,
            "businessId": businessID,
            "taxYear": taxYear,
            "fraudPreventionHeaders": headers,
        ]
    }

    private func query<Response: Decodable>(
        _ request: GraphQLRequest<Response>
    ) async throws -> Response {
        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let response): return response
        case .failure(let error): throw error
        }
    }

    private func mutate<Response: Decodable>(
        _ request: GraphQLRequest<Response>
    ) async throws -> Response {
        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let response): return response
        case .failure(let error): throw error
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    mutating func add(_ value: String?, for key: String) {
        if let value, !value.isEmpty { self[key] = value }
    }
}
