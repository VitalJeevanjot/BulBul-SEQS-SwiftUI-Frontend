import Amplify
import Foundation

protocol HMRCBusinessAPIProtocol: Sendable {
    func getTokenStatus() async throws -> HMRCTokenStatusResult
    func refreshAccessToken() async throws -> HMRCOAuthTokenResult
    func listBusinesses(nino: String) async throws -> HMRCListBusinessesResult
    func retrieveBusinessDetails(nino: String, businessID: String) async throws -> HMRCRetrieveBusinessDetailsResult
}

struct HMRCBusinessAPI: HMRCBusinessAPIProtocol {
    func getTokenStatus() async throws -> HMRCTokenStatusResult {
        let request = GraphQLRequest<HMRCTokenStatusResult>(
            document: """
            query GetHmrcTokenStatus {
                getHmrcTokenStatus {
                    success
                    data {
                        isSignedInWithHmrc
                    }
                    error {
                        statusCode
                        code
                        message
                        correlationId
                    }
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
                    token {
                        tokenType
                        expiresIn
                        expiresAt
                        scope
                    }
                    error {
                        statusCode
                        error
                        errorDescription
                    }
                }
            }
            """,
            responseType: HMRCOAuthTokenResult.self,
            decodePath: "refreshAccessToken"
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func listBusinesses(nino: String) async throws -> HMRCListBusinessesResult {
        let request = GraphQLRequest<HMRCListBusinessesResult>(
            document: """
            query ListBusinesses($nino: String!) {
                listBusinesses(nino: $nino) {
                    success
                    data {
                        listOfBusinesses {
                            typeOfBusiness
                            businessId
                            tradingName
                        }
                    }
                    error {
                        statusCode
                        code
                        message
                        correlationId
                    }
                }
            }
            """,
            variables: ["nino": nino],
            responseType: HMRCListBusinessesResult.self,
            decodePath: "listBusinesses"
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let response):
            print("[HMRC] listBusinesses response: \(String(reflecting: response))")
            return response
        case .failure(let error):
            throw error
        }
    }

    func retrieveBusinessDetails(
        nino: String,
        businessID: String
    ) async throws -> HMRCRetrieveBusinessDetailsResult {
        let request = GraphQLRequest<HMRCRetrieveBusinessDetailsResult>(
            document: """
            query RetrieveBusinessDetails($nino: String!, $businessId: String!) {
                retrieveBusinessDetails(nino: $nino, businessId: $businessId) {
                    success
                    data {
                        businessId
                        typeOfBusiness
                        tradingName
                        yearOfMigration
                        firstAccountingPeriodStartDate
                        firstAccountingPeriodEndDate
                        latencyDetails {
                            latencyEndDate
                            taxYear1
                            latencyIndicator1
                            taxYear2
                            latencyIndicator2
                        }
                        quarterlyTypeChoice {
                            quarterlyPeriodType
                            taxYearOfChoice
                        }
                        accountingPeriods {
                            start
                            end
                        }
                        commencementDate
                        cessationDate
                        businessAddressLineOne
                        businessAddressLineTwo
                        businessAddressLineThree
                        businessAddressLineFour
                        businessAddressPostcode
                        businessAddressCountryCode
                    }
                    error {
                        statusCode
                        code
                        message
                        correlationId
                    }
                }
            }
            """,
            variables: ["nino": nino, "businessId": businessID],
            responseType: HMRCRetrieveBusinessDetailsResult.self,
            decodePath: "retrieveBusinessDetails"
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let response):
            print("[HMRC] retrieveBusinessDetails(\(businessID)) response: \(String(reflecting: response))")
            return response
        case .failure(let error):
            throw error
        }
    }

    private func query<Response: Decodable>(
        _ request: GraphQLRequest<Response>
    ) async throws -> Response {
        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
