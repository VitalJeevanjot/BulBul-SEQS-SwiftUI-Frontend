//
//  ContentView.swift
//  BulBul-SEQS
//
//  Created by Jeevanjot Singh on 26/05/26.
//

import Amplify
import Authenticator
import AWSPluginsCore
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var startupSessionCheckComplete = false

    var body: some View {
        Group {
            if startupSessionCheckComplete {
                Authenticator {
                    state in
                    MainView(
                        onSignOut: {
                            Task { @MainActor in
                                _ = await state.signOut()
                                deleteLocalUserData()
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard !startupSessionCheckComplete else {
                return
            }

            await validateStartupAuthSession()
            startupSessionCheckComplete = true
        }
    }

    private func validateStartupAuthSession() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession(
                options: .forceRefresh()
            )

            guard session.isSignedIn else {
                return
            }

            guard let cognitoSession = session as? AuthCognitoTokensProvider else {
                return
            }

            if case .failure(let authError) = cognitoSession.getCognitoTokens(),
               authError.requiresReauthentication {
                _ = await Amplify.Auth.signOut()
                deleteLocalUserData()
            }
        } catch {
            print("Unable to validate startup auth session: \(error)")
        }
    }

    @MainActor
    private func deleteLocalUserData() {
        do {
            try LocalUserDataStore.deleteAll(from: modelContext)
        } catch {
            print("Unable to delete local user data after sign-out: \(error)")
        }
    }
}

private extension AuthError {
    var requiresReauthentication: Bool {
        switch self {
        case .notAuthorized, .sessionExpired, .signedOut:
            return true
        default:
            return false
        }
    }
}

#Preview {
    ContentView()
}
