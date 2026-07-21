import SwiftUI

struct CumulativeSummaryView: View {
    let business: StoredBusiness

    @State private var fromYear = Calendar.current.component(.year, from: Date()) - 1
    @State private var toYear = Calendar.current.component(.year, from: Date())
    @State private var consolidated: HMRCConsolidatedCumulativeSummary?
    @State private var nonConsolidated: HMRCNonConsolidatedCumulativeSummary?
    @State private var consolidatedError: String?
    @State private var nonConsolidatedError: String?
    @State private var isFetching = false

    private var selectableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 6)...(current + 1))
    }

    private var taxYear: String {
        String(format: "%04d-%02d", fromYear, toYear % 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if business.typeOfBusiness.caseInsensitiveCompare("self-employment") != .orderedSame {
                ContentUnavailableView(
                    "Self-employment only",
                    systemImage: "briefcase",
                    description: Text("Cumulative period summaries are available for self-employment businesses.")
                )
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                GroupBox("Tax year") {
                    HStack(spacing: 14) {
                        Picker("From", selection: $fromYear) {
                            ForEach(selectableYears, id: \.self) { Text(String($0)).tag($0) }
                        }
                        .onChange(of: fromYear) { _, newValue in toYear = newValue + 1 }
                        .disabled(isFetching)

                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)

                        Picker("To", selection: $toYear) {
                            Text(String(fromYear + 1)).tag(fromYear + 1)
                        }
                        .disabled(isFetching)

                        Spacer()

                        Button(isFetching ? "Fetching…" : "Fetch", systemImage: "arrow.down.doc") {
                            Task { await fetch() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isFetching)
                    }
                    .padding(.top, 6)
                }

                if isFetching { ProgressView("Fetching both summary formats…") }

                summarySection(
                    title: "Consolidated",
                    systemImage: "sum",
                    error: consolidatedError
                ) {
                    if let consolidated {
                        periodRows(consolidated.periodDates)
                        incomeRows(consolidated.periodIncome)
                        if let value = consolidated.periodExpenses?.consolidatedExpenses {
                            valueRow("Consolidated expenses", value)
                        }
                    } else if consolidatedError == nil {
                        Text(nonConsolidated == nil
                             ? "Fetch a tax year to view the consolidated summary."
                             : "No consolidated summary was returned for this tax year.")
                            .foregroundStyle(.secondary)
                    }
                }

                summarySection(
                    title: "Non-consolidated",
                    systemImage: "list.bullet.rectangle",
                    error: nonConsolidatedError
                ) {
                    if let nonConsolidated {
                        periodRows(nonConsolidated.periodDates)
                        incomeRows(nonConsolidated.periodIncome)
                        keyedRows(title: "Period expenses", values: nonConsolidated.periodExpenses?.keyedValues ?? [:])
                        keyedRows(title: "Disallowable expenses", values: nonConsolidated.periodDisallowableExpenses?.keyedValues ?? [:])
                    } else if nonConsolidatedError == nil {
                        Text(consolidated == nil
                             ? "Fetch a tax year to view the non-consolidated summary."
                             : "No non-consolidated summary was returned for this tax year.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func summarySection<Content: View>(
        title: String,
        systemImage: String,
        error: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage).font(.title3.bold()).foregroundStyle(.indigo)
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.hmrcCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.secondary.opacity(0.12)) }
    }

    @ViewBuilder
    private func periodRows(_ dates: HMRCCumulativePeriodDates) -> some View {
        LabeledContent("Period starts", value: dates.periodStartDate)
        LabeledContent("Period ends", value: dates.periodEndDate)
    }

    @ViewBuilder
    private func incomeRows(_ income: HMRCCumulativeIncome?) -> some View {
        if let value = income?.turnover { valueRow("Turnover", value) }
        if let value = income?.other { valueRow("Other income", value) }
        if let value = income?.taxTakenOffTradingIncome { valueRow("Tax taken off trading income", value) }
    }

    @ViewBuilder
    private func keyedRows(title: String, values: [String: Double]) -> some View {
        if !values.isEmpty {
            Divider()
            Text(title).font(.headline)
            ForEach(values.keys.sorted(), id: \.self) { key in
                valueRow(HMRCCategory(rawValue: key)?.title ?? key, values[key, default: 0])
            }
        }
    }

    private func valueRow(_ title: String, _ value: Double) -> some View {
        LabeledContent(title, value: value, format: .currency(code: "GBP"))
    }

    @MainActor
    private func fetch() async {
        toYear = fromYear + 1
        let requestedTaxYear = taxYear
        isFetching = true
        consolidated = nil
        nonConsolidated = nil
        consolidatedError = nil
        nonConsolidatedError = nil
        defer { isFetching = false }
        let api = HMRCBusinessAPI()

        do {
            let result = try await api.getSelfEmploymentCumulativeSummaryConsolidated(
                nino: business.nino,
                businessID: business.businessID,
                taxYear: requestedTaxYear
            )
            if result.success { consolidated = result.data }
            else { consolidatedError = result.error?.message ?? "No consolidated summary was returned." }
        } catch {
            consolidatedError = error.localizedDescription
        }

        do {
            let result = try await api.getSelfEmploymentCumulativeSummaryNonConsolidated(
                nino: business.nino,
                businessID: business.businessID,
                taxYear: requestedTaxYear
            )
            if result.success { nonConsolidated = result.data }
            else { nonConsolidatedError = result.error?.message ?? "No non-consolidated summary was returned." }
        } catch {
            nonConsolidatedError = error.localizedDescription
        }

        if consolidated != nil || nonConsolidated != nil {
            consolidatedError = nil
            nonConsolidatedError = nil
        }
    }
}
