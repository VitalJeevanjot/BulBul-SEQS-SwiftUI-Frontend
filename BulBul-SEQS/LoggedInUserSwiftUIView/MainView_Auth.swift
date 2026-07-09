//
//  Untitled.swift
//  BulBul-SEQS
//
//  Created by Jeevanjot Singh on 14/06/26.
//
// ERROR LISTING NUMBER: 1

import Amplify
import AuthenticationServices
import Foundation
import SwiftUI

struct HMRCAuthPromptError: Error, Identifiable {
    let id = UUID()
    let code: String
    let description: String
    let underlyingError: Error?

    init(code: String, description: String, underlyingError: Error? = nil) {
        self.code = code
        self.description = description
        self.underlyingError = underlyingError
    }
}
enum HMRCAuthCallback {
    static func authorizationCode(
        from callbackURL: URL,
        expectedState: String
    ) throws -> String {
        guard let components = URLComponents(
            url: callbackURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw HMRCAuthPromptError(
                code: "BulBul-Seqs-1D",
                description: "The MTD callback URL could not be read."
            )
        }
        guard let queryItems = components.queryItems else {
            throw HMRCAuthPromptError(
                code: "BulBul-Seqs-1E",
                description: "The MTD callback did not contain any response parameters."
            )
        }

        func value(for name: String) -> String? {
            queryItems.first { $0.name == name }?.value
        }

        if let providerError = value(for: "error") {
            let providerCode = value(for: "error_code")
                .map { " Provider code: \($0)." } ?? ""
            let providerDescription = value(for: "error_description")
                ?? "No description was provided by MTD."
            throw HMRCAuthPromptError(
                code: "BulBul-Seqs-1F",
                description:
                    "MTD returned \(providerError).\(providerCode) \(providerDescription)"
            )
        }

        guard let code = value(for: "code"), let state = value(for: "state") else {
            throw HMRCAuthPromptError(
                code: "BulBul-Seqs-1G",
                description: "The MTD callback was missing its authorization code or state."
            )
        }
        guard state == expectedState else {
            throw HMRCAuthPromptError(
                code: "BulBul-Seqs-1H",
                description: "The MTD callback state did not match the authentication request."
            )
        }

        return code
    }
}

extension MainView {
    @MainActor
    func AuthenticateWithHMRC() async {
        guard let configuration = AppConfig.hmrc else {
            presentHMRCAuthError(
                HMRCAuthPromptError(
                    code: "BulBul-Seqs-1I",
                    description: "The local MTD configuration is missing or invalid."
                )
            )
            return
        }

        let stateUUID = UUID().uuidString

        let urlQueryItems: [URLQueryItem] = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: configuration.clientID),
            .init(
                name: "scope",
                value: "write:self-assessment read:self-assessment"
            ),
            .init(name: "state", value: stateUUID),
            .init(name: "redirect_uri", value: configuration.redirectURI),
        ]

        guard var components = URLComponents(
            url: configuration.authURL,
            resolvingAgainstBaseURL: false
        ) else {
            presentHMRCAuthError(
                HMRCAuthPromptError(
                    code: "BulBul-Seqs-1A",
                    description: "Could not create the MTD authentication URL."
                )
            )
            return
        }
        components.queryItems = urlQueryItems

        guard let urlToAuthWith = components.url else {
            presentHMRCAuthError(
                HMRCAuthPromptError(
                    code: "BulBul-Seqs-1B",
                    description: "Could not add the required parameters to the MTD authentication URL."
                )
            )
            return
        }

        do {
            let callBackURL = try await webAuthSession.authenticate(
                using: urlToAuthWith,
                callback: .customScheme(configuration.redirectScheme),
                preferredBrowserSession: .ephemeral,
                additionalHeaderFields: [:]
            )
            let code = try HMRCAuthCallback.authorizationCode(
                from: callBackURL,
                expectedState: stateUUID
            )
            try await changeToAccessToken(with: code, stateID: stateUUID)
        } catch {
            let promptError = error as? HMRCAuthPromptError
                ?? HMRCAuthPromptError(
                    code: "BulBul-Seqs-1C",
                    description: "MTD authentication could not be completed. \(error.localizedDescription)",
                    underlyingError: error
                )
            presentHMRCAuthError(promptError)
        }
    }

    @MainActor
    private func presentHMRCAuthError(_ error: HMRCAuthPromptError) {
        print("[\(error.code)] \(error.description)")
        if let underlyingError = error.underlyingError {
            print("[\(error.code)] Full error object:")
            dump(underlyingError)
            print("[\(error.code)] Error description: \(underlyingError.localizedDescription)")
        }
        hmrcAuthError = error
    }

    private func changeToAccessToken(
        with code: String,
        stateID: String
    ) async throws {
        let request = GraphQLRequest<Bool>(
            document: """
            mutation ChangeToAccessToken($input: String!, $stateId: String!) {
                changeToAccessToken(input: $input, stateId: $stateId)
            }
            """,
            variables: ["input": code, "stateId": stateID],
            responseType: Bool.self,
            decodePath: "changeToAccessToken"
        )

        let result = try await Amplify.API.mutate(request: request)

        switch result {
        case .success(true):
            return
        case .success(false):
            throw HMRCAuthPromptError(
                code: "BulBul-Seqs-1J",
                description: "MTD authentication did not complete successfully."
            )
        case .failure(let error):
            throw error
        }
    }
}
