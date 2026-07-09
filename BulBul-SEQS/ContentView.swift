//
//  ContentView.swift
//  BulBul-SEQS
//
//  Created by Jeevanjot Singh on 26/05/26.
//

import Amplify
import Authenticator
import AWSPluginsCore
import SwiftUI

struct ContentView: View {
    @State private var startupSessionCheckComplete = false

    var body: some View {
        Group {
            if startupSessionCheckComplete {
                Authenticator {
                    state in
                    MainView()
                    Button("Sign out") {
                        Task {
                            await state.signOut()
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
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
            }
        } catch {
            print("Unable to validate startup auth session: \(error)")
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
