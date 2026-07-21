import Amplify
import AWSCognitoAuthPlugin
import SwiftUI

struct MandatoryMFAGate<Content: View>: View {
    @State private var status = GateStatus.checking
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            switch status {
            case .checking:
                ProgressView("Checking two-factor authentication…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { await checkMFA() }
            case .ready:
                content()
            case .setupRequired:
                MFASettingsView(isMandatory: true) {
                    status = .ready
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Unable to verify 2FA", systemImage: "lock.trianglebadge.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await checkMFA() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    @MainActor
    private func checkMFA() async {
        status = .checking
        do {
            let plugin = try cognitoPlugin()
            let preference = try await plugin.fetchMFAPreference()
            status = preference.enabled?.contains(.totp) == true ? .ready : .setupRequired
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}

struct MFASettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let isMandatory: Bool
    var onCompleted: () -> Void = {}

    @State private var preferenceText = "Checking…"
    @State private var setupDetails: TOTPSetupDetails?
    @State private var setupURI: URL?
    @State private var verificationCode = ""
    @State private var isWorking = false
    @State private var isConfigured = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Two-factor authentication") {
                    LabeledContent("Status", value: preferenceText)

                    if let successMessage {
                        Label(successMessage, systemImage: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if let setupDetails {
                    Section("Connect an authenticator") {
                        Text("Add this account to Apple Passwords, Microsoft Authenticator, Google Authenticator, or another TOTP app.")
                            .foregroundStyle(.secondary)

                        if let setupURI {
                            Link(destination: setupURI) {
                                Label("Open authenticator app", systemImage: "lock.open.display")
                            }
                        }

                        LabeledContent("Setup key") {
                            Text(setupDetails.sharedSecret)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                                .multilineTextAlignment(.trailing)
                        }

                        TextField("6-digit code", text: $verificationCode)
                            .textContentType(.oneTimeCode)
#if os(iOS)
                            .keyboardType(.numberPad)
#endif

                        Button("Verify and require TOTP") {
                            Task { await verify() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isWorking || verificationCode.count != 6)
                    }
                } else {
                    Section {
                        Button(isConfigured ? "Replace authenticator setup" : "Set up authenticator") {
                            Task { await beginSetup() }
                        }
                        .disabled(isWorking)
                    } footer: {
                        Text("A new setup replaces the TOTP secret used for future sign-ins. Store the new account in your authenticator before verifying it.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isMandatory ? "2FA required" : "2FA settings")
            .toolbar {
                if !isMandatory {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .overlay {
                if isWorking {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .task { await loadPreference() }
        }
#if os(macOS)
        .frame(minWidth: 520, idealWidth: 600, minHeight: 480)
#endif
    }

    @MainActor
    private func loadPreference() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let preference = try await cognitoPlugin().fetchMFAPreference()
            isConfigured = preference.enabled?.contains(.totp) == true
            preferenceText = isConfigured
                ? (preference.preferred == .totp ? "TOTP enabled and preferred" : "TOTP enabled")
                : "Setup required"
            if isMandatory && !isConfigured { await beginSetup() }
        } catch {
            preferenceText = "Could not check"
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func beginSetup() async {
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }
        do {
            let details = try await Amplify.Auth.setUpTOTP()
            setupDetails = details
            setupURI = try details.getSetupURI(appName: "BulBul SEQS")
            preferenceText = "Waiting for verification"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func verify() async {
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }
        do {
            try await Amplify.Auth.verifyTOTPSetup(code: verificationCode)
            try await cognitoPlugin().updateMFAPreference(totp: .preferred)
            isConfigured = true
            preferenceText = "TOTP enabled and preferred"
            successMessage = "Two-factor authentication is ready."
            setupDetails = nil
            setupURI = nil
            verificationCode = ""
            onCompleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum GateStatus {
    case checking
    case ready
    case setupRequired
    case failed(String)
}

private func cognitoPlugin() throws -> AWSCognitoAuthPlugin {
    guard let plugin = try Amplify.Auth.getPlugin(for: "awsCognitoAuthPlugin") as? AWSCognitoAuthPlugin else {
        throw MFASettingsError.pluginUnavailable
    }
    return plugin
}

private enum MFASettingsError: LocalizedError {
    case pluginUnavailable

    var errorDescription: String? { "The Cognito authentication plugin is unavailable." }
}
