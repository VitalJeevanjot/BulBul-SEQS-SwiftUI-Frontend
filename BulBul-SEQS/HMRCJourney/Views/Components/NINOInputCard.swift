import SwiftUI

struct NINOInputCard: View {
    @Binding var nino: String
    let isValid: Bool
    let isLoading: Bool
    let submit: () -> Void

    private var validationMessage: String {
        if nino.isEmpty {
            return "We’ll securely use it to find your HMRC businesses."
        }
        return isValid
            ? "Your NINO format looks good."
            : "Use two letters, six digits and A, B, C or D."
    }

    var body: some View {
        GroupBox("National Insurance number") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Enter your NINO to verify it with HMRC and load your businesses.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("AB123456C", text: $nino)
                    .font(.body.monospaced().weight(.semibold))
                    .textFieldStyle(.roundedBorder)
#if os(iOS)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
#endif
                    .accessibilityIdentifier("nino-input")

                Label(
                    validationMessage,
                    systemImage: isValid && !nino.isEmpty ? "checkmark.circle.fill" : "info.circle"
                )
                .font(.caption)
                .foregroundStyle(isValid && !nino.isEmpty ? .green : .secondary)

                Button(action: submit) {
                    if isLoading {
                        ProgressView()
                    }
                    Text(isLoading ? "Loading businesses…" : "Get my businesses")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isLoading)
                .accessibilityIdentifier("get-businesses-button")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        }
    }
}

extension Color {
    static var hmrcCardBackground: Color {
#if os(iOS)
        Color(uiColor: .secondarySystemBackground)
#elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
#else
        Color.secondary.opacity(0.08)
#endif
    }
}
