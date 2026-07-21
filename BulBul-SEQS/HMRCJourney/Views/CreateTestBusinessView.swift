import SwiftUI

struct CreateTestBusinessView: View {
    @Environment(\.dismiss) private var dismiss

    let submit: (HMRCCreateTestBusinessPayload) async throws -> String

    @State private var payload = HMRCCreateTestBusinessPayload()
    @State private var includesQuarterlyChoice = false
    @State private var includesLatencyDetails = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        guard !payload.typeOfBusiness.isEmpty else { return false }
        if includesQuarterlyChoice {
            guard hasValue(payload.quarterlyPeriodType), hasValue(payload.taxYearOfChoice) else { return false }
        }
        if includesLatencyDetails {
            guard hasValue(payload.latencyEndDate), hasValue(payload.latencyTaxYear1),
                  hasValue(payload.latencyIndicator1), hasValue(payload.latencyTaxYear2),
                  hasValue(payload.latencyIndicator2) else { return false }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Business type *", selection: $payload.typeOfBusiness) {
                        Text("Self-employment").tag("self-employment")
                        Text("UK property").tag("uk-property")
                        Text("Foreign property").tag("foreign-property")
                    }
                    optionalField("Trading name", value: $payload.tradingName)
                    optionalField("Accounting type", value: $payload.accountingType)
                } header: {
                    Text("Business")
                } footer: {
                    Text("Fields marked * are required.")
                }

                Section("Accounting dates (YYYY-MM-DD)") {
                    optionalField("First period start", value: $payload.firstAccountingPeriodStartDate)
                    optionalField("First period end", value: $payload.firstAccountingPeriodEndDate)
                    optionalField("Commencement", value: $payload.commencementDate)
                    optionalField("Cessation", value: $payload.cessationDate)
                }

                Section("Quarterly type choice") {
                    Toggle("Include quarterly choice", isOn: $includesQuarterlyChoice)
                    if includesQuarterlyChoice {
                        requiredField("Quarterly period type *", value: optionalBinding($payload.quarterlyPeriodType))
                        requiredField("Tax year of choice *", value: optionalBinding($payload.taxYearOfChoice))
                    }
                }

                Section("Latency details") {
                    Toggle("Include latency details", isOn: $includesLatencyDetails)
                    if includesLatencyDetails {
                        requiredField("Latency end date *", value: optionalBinding($payload.latencyEndDate))
                        requiredField("Tax year 1 *", value: optionalBinding($payload.latencyTaxYear1))
                        requiredField("Latency indicator 1 *", value: optionalBinding($payload.latencyIndicator1))
                        requiredField("Tax year 2 *", value: optionalBinding($payload.latencyTaxYear2))
                        requiredField("Latency indicator 2 *", value: optionalBinding($payload.latencyIndicator2))
                    }
                }

                Section("Business address") {
                    optionalField("Address line 1", value: $payload.businessAddressLineOne)
                    optionalField("Address line 2", value: $payload.businessAddressLineTwo)
                    optionalField("Address line 3", value: $payload.businessAddressLineThree)
                    optionalField("Address line 4", value: $payload.businessAddressLineFour)
                    optionalField("Postcode", value: $payload.businessAddressPostcode)
                    optionalField("Country code", value: $payload.businessAddressCountryCode)
                }

                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create test business")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Creating…" : "Create") { Task { await create() } }
                        .disabled(!canSubmit || isSubmitting)
                }
            }
            .overlay { if isSubmitting { ProgressView().controlSize(.large) } }
            .onChange(of: includesQuarterlyChoice) { _, included in
                if !included { payload.quarterlyPeriodType = nil; payload.taxYearOfChoice = nil }
            }
            .onChange(of: includesLatencyDetails) { _, included in
                if !included {
                    payload.latencyEndDate = nil
                    payload.latencyTaxYear1 = nil
                    payload.latencyIndicator1 = nil
                    payload.latencyTaxYear2 = nil
                    payload.latencyIndicator2 = nil
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 620, idealWidth: 700, minHeight: 720)
#endif
    }

    private func optionalField(_ title: String, value: Binding<String?>) -> some View {
        TextField(title, text: optionalBinding(value))
    }

    private func requiredField(_ title: String, value: Binding<String>) -> some View {
        TextField(title, text: value)
    }

    private func optionalBinding(_ binding: Binding<String?>) -> Binding<String> {
        Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    private func hasValue(_ value: String?) -> Bool {
        !(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    @MainActor
    private func create() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await submit(payload)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
