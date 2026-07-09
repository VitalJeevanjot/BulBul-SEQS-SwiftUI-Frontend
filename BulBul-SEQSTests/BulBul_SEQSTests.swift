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

}
