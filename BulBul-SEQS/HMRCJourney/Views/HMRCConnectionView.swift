import SwiftUI

enum HMRCConnectionState: Equatable {
    case checking
    case connected
    case needsSignIn(String)
}

struct HMRCConnectionView: View {
    let state: HMRCConnectionState
    let isAuthenticating: Bool
    let authenticate: () -> Void

    var body: some View {
        GroupBox("HMRC account") {
            VStack(alignment: .leading, spacing: 12) {
                switch state {
                case .checking:
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Checking your HMRC sign-in…")
                    }

                case .connected:
                    Label("Signed in with HMRC", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Text("You can re-sign in if you want to use a different HMRC account.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    authButton(title: "Re-sign in with HMRC")

                case .needsSignIn(let message):
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    authButton(title: "Sign in with HMRC")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        }
    }

    private func authButton(title: String) -> some View {
        Button(action: authenticate) {
            HStack(spacing: 8) {
                if isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(isAuthenticating ? "Opening HMRC…" : title)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isAuthenticating)
        .accessibilityIdentifier("hmrc-sign-in-button")
    }
}
