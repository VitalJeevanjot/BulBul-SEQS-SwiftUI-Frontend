//
//  BulBul_SEQSTests.swift
//  BulBul-SEQSTests
//
//  Created by Jeevanjot Singh on 26/05/26.
//

import Testing
import Foundation
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

}
