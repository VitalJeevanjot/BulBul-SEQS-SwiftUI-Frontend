//
//  MainView.swift
//  BulBul-SEQS
//
//  Created by Jeevanjot Singh on 14/06/26.
//

import AuthenticationServices
import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.webAuthenticationSession) var webAuthSession

    @State private var viewModel = HMRCJourneyViewModel()
    @State var hmrcAuthError: HMRCAuthPromptError?
    @State var isShowingHMRCSignInSuccess = false
    @State var hmrcConnectionState = HMRCConnectionState.checking
    @State var isAuthenticatingWithHMRC = false
    @Namespace private var businessZoomNamespace

    var onSignOut: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    UserHeaderView(
                        displayName: viewModel.userDisplayName,
                        signOut: onSignOut
                    )

                    HMRCConnectionView(
                        state: hmrcConnectionState,
                        isAuthenticating: isAuthenticatingWithHMRC,
                        authenticate: { Task { await AuthenticateWithHMRC() } }
                    )

                    if hmrcConnectionState == .connected {
                        NINOInputCard(
                            nino: Binding(
                                get: { viewModel.ninoInput },
                                set: { viewModel.updateNINOInput($0) }
                            ),
                            isValid: viewModel.isNINOValid,
                            isLoading: viewModel.isLoading,
                            submit: {
                                Task { await viewModel.getBusinesses(modelContext: modelContext) }
                            }
                        )

                        if let progressMessage = viewModel.progressMessage {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text(progressMessage)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .accessibilityIdentifier("business-loading-status")
                        }

                        if let successMessage = viewModel.successMessage {
                            Label(successMessage, systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ForEach(viewModel.issues) { issue in
                            HMRCIssueCard(issue: issue)
                        }

                        if !viewModel.businesses.isEmpty {
                            BusinessesListView(
                                businesses: viewModel.businesses,
                                namespace: businessZoomNamespace
                            )
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
            .background(Color.primary.opacity(0.025))
            .navigationTitle("BulBul SEQS")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
        .task {
            print("loading profile...")
            await viewModel.load(modelContext: modelContext)
            await checkHMRCConnection()
        }
        .alert(item: $hmrcAuthError) { error in
            Alert(
                title: Text("MTD Authentication Error"),
                message: Text("\(error.code)\n\(error.description)"),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Sign in successful", isPresented: $isShowingHMRCSignInSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You’re now signed in with HMRC.")
        }
    }

    @MainActor
    private func checkHMRCConnection() async {
        hmrcConnectionState = .checking

        do {
            let api = HMRCBusinessAPI()
            let result = try await api.getTokenStatus()

            guard result.success, let status = result.data else {
                hmrcConnectionState = .needsSignIn(
                    result.error?.message ?? "Sign in with HMRC to continue."
                )
                return
            }

            if status.isSignedInWithHmrc {
                hmrcConnectionState = .connected
            } else {
                hmrcConnectionState = .needsSignIn("Sign in with HMRC to continue.")
            }
        } catch {
            hmrcConnectionState = .needsSignIn(
                "We could not check your HMRC session. Please sign in to continue."
            )
            print("[HMRC] Token status check failed: \(error)")
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: [HMRCUserProfile.self, StoredBusiness.self], inMemory: true)
}
