import SwiftData
import SwiftUI

struct ObligationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var business: StoredBusiness

    @State private var selectedObligation: StoredObligation?
    @State private var isCreatingCustomPeriod = false
    @State private var isRefreshing = false
    @State private var message: String?
    @State private var issue: HMRCJourneyIssue?

    private var obligations: [StoredObligation] {
        business.obligations.sorted {
            if $0.periodStartDate == $1.periodStartDate { return $0.dueDate < $1.dueDate }
            return $0.periodStartDate < $1.periodStartDate
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Income and expenditure obligations")
                        .font(.title2.bold())
                    if let fetchedAt = business.obligationsFetchedAt {
                        Text("Last fetched \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if business.typeOfBusiness.caseInsensitiveCompare("self-employment") == .orderedSame {
                    Button("Custom period summary", systemImage: "calendar.badge.plus") {
                        isCreatingCustomPeriod = true
                    }
                    .buttonStyle(.bordered)
                }
                Button(isRefreshing ? "Fetching…" : "Re-fetch", systemImage: "arrow.clockwise") {
                    Task { await refresh() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRefreshing)
            }

            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            if let issue { HMRCIssueCard(issue: issue) }

            if obligations.isEmpty {
                ContentUnavailableView(
                    "No obligations",
                    systemImage: "calendar.badge.checkmark",
                    description: Text("HMRC returned no income and expenditure obligations for this business.")
                )
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                    ForEach(obligations) { obligation in
                        obligationCard(obligation)
                    }
                }
            }
        }
        .sheet(item: $selectedObligation) { obligation in
            ObligationSubmissionView(business: business, obligation: obligation)
        }
        .sheet(isPresented: $isCreatingCustomPeriod) {
            ObligationSubmissionView(business: business)
        }
    }

    private func obligationCard(_ obligation: StoredObligation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(obligation.status.capitalized, systemImage: obligation.status.lowercased() == "fulfilled" ? "checkmark.circle.fill" : "clock.fill")
                    .font(.headline)
                    .foregroundStyle(obligation.status.lowercased() == "fulfilled" ? .green : .orange)
                Spacer()
                Text(obligation.typeOfBusiness.replacingOccurrences(of: "-", with: " ").capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            obligationRow("Period starts", obligation.periodStartDate)
            obligationRow("Period ends", obligation.periodEndDate)
            obligationRow("Due", obligation.dueDate)
            if let receivedDate = obligation.receivedDate { obligationRow("Received", receivedDate) }

            if let actionTitle = obligation.actionTitle {
                Button(actionTitle, systemImage: actionTitle == "Amend" ? "pencil" : "paperplane.fill") {
                    selectedObligation = obligation
                }
                .buttonStyle(.borderedProminent)
                .tint(actionTitle == "Amend" ? .orange : .blue)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.hmrcCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.secondary.opacity(0.12)) }
    }

    private func obligationRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
        }
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true
        message = nil
        issue = nil
        defer { isRefreshing = false }
        do {
            try await BusinessObligationStore.refresh(business: business, modelContext: modelContext)
            message = "Obligations refreshed and saved."
        } catch let error as HMRCAPIError {
            issue = HMRCJourneyIssue(title: "HMRC could not refresh obligations", apiError: error)
        } catch {
            issue = HMRCJourneyIssue(title: "Could not refresh obligations", message: error.localizedDescription)
        }
    }
}

private struct ObligationSubmissionView: View {
    @Environment(\.dismiss) private var dismiss

    let business: StoredBusiness
    let obligation: StoredObligation?

    @State private var draft: HMRCCumulativeSummaryDraft
    @State private var consolidatedExpenseAmount: Double
    @State private var isSubmitting = false
    @State private var message: String?
    @State private var errorMessage: String?

    init(business: StoredBusiness, obligation: StoredObligation? = nil) {
        self.business = business
        self.obligation = obligation
        let recordDates = business.digitalRecords.map(\.date)
        let startDate = obligation.flatMap { HMRCDate.date(from: $0.periodStartDate) }
            ?? recordDates.min()
            ?? Date()
        let endDate = obligation.flatMap { HMRCDate.date(from: $0.periodEndDate) }
            ?? recordDates.max()
            ?? startDate
        let calculated = HMRCCumulativeSummaryCalculator.calculate(
            records: business.digitalRecords,
            periodStartDate: HMRCDate.string(from: startDate),
            periodEndDate: HMRCDate.string(from: max(startDate, endDate))
        )
        _draft = State(initialValue: calculated)
        _consolidatedExpenseAmount = State(initialValue: calculated.consolidatedExpenses)
    }

    var body: some View {
        NavigationStack {
            TabView {
                Tab("Consolidated", systemImage: "sum") {
                    Form {
                        commonSections
                        Section("Consolidated expenses") {
                            moneyField("Consolidated expenses", value: $consolidatedExpenseAmount)
                        }
                        submitSection(mode: .consolidated)
                    }
                    .formStyle(.grouped)
                }

                Tab("Non-consolidated", systemImage: "list.bullet.rectangle") {
                    Form {
                        commonSections
                        Section("Period expenses") {
                            ForEach(HMRCCategory.expenseCategories) { category in
                                moneyField(category.title, value: dictionaryBinding(category.rawValue, in: .expenses))
                            }
                        }
                        Section("Period disallowable expenses") {
                            ForEach(HMRCCategory.disallowableCategories) { category in
                                moneyField(category.title, value: dictionaryBinding(category.rawValue, in: .disallowable))
                            }
                        }
                        submitSection(mode: .nonConsolidated)
                    }
                    .formStyle(.grouped)
                }
            }
            .navigationTitle("Submit SE Cumulative Period Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .overlay {
                if isSubmitting {
                    ProgressView("Submitting to HMRC…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 720, idealWidth: 820, minHeight: 700)
#endif
    }

    @ViewBuilder
    private var commonSections: some View {
        Section(obligation == nil ? "Custom period" : "Obligation period") {
            if obligation == nil {
                DatePicker("Start", selection: periodStartBinding, in: ...periodEndDate, displayedComponents: .date)
                DatePicker("End", selection: periodEndBinding, in: periodStartDate..., displayedComponents: .date)
                Text("Changing the dates recalculates the values from this business’s digital records.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent("Start", value: draft.periodStartDate)
                LabeledContent("End", value: draft.periodEndDate)
            }
            LabeledContent("Tax year", value: HMRCDate.taxYear(containing: draft.periodEndDate))
        }
        Section("Period income") {
            moneyField("Turnover", value: $draft.turnover)
            moneyField("Other income", value: $draft.otherIncome)
            moneyField("Tax taken off trading income", value: $draft.taxTakenOffTradingIncome)
        }
    }

    private func submitSection(mode: SubmissionMode) -> some View {
        Section {
            if let message { Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            if let errorMessage { Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            Button("Submit \(mode.title)", systemImage: "paperplane.fill") {
                Task { await submit(mode) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)
        }
    }

    private func moneyField(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField("0.00", value: value, format: .currency(code: "GBP"))
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 120, idealWidth: 160)
        }
    }

    private enum DictionaryKind { case expenses, disallowable }

    private var periodStartDate: Date {
        HMRCDate.date(from: draft.periodStartDate) ?? Date()
    }

    private var periodEndDate: Date {
        HMRCDate.date(from: draft.periodEndDate) ?? periodStartDate
    }

    private var periodStartBinding: Binding<Date> {
        Binding(
            get: { periodStartDate },
            set: { recalculate(startDate: $0, endDate: max($0, periodEndDate)) }
        )
    }

    private var periodEndBinding: Binding<Date> {
        Binding(
            get: { periodEndDate },
            set: { recalculate(startDate: min(periodStartDate, $0), endDate: $0) }
        )
    }

    private func recalculate(startDate: Date, endDate: Date) {
        let calculated = HMRCCumulativeSummaryCalculator.calculate(
            records: business.digitalRecords,
            periodStartDate: HMRCDate.string(from: startDate),
            periodEndDate: HMRCDate.string(from: endDate)
        )
        draft = calculated
        consolidatedExpenseAmount = calculated.consolidatedExpenses
        message = nil
        errorMessage = nil
    }

    private func dictionaryBinding(_ key: String, in kind: DictionaryKind) -> Binding<Double> {
        Binding {
            switch kind {
            case .expenses: draft.expenses[key, default: 0]
            case .disallowable: draft.disallowableExpenses[key, default: 0]
            }
        } set: { value in
            switch kind {
            case .expenses: draft.expenses[key] = max(value, 0)
            case .disallowable: draft.disallowableExpenses[key] = max(value, 0)
            }
        }
    }

    @MainActor
    private func submit(_ mode: SubmissionMode) async {
        isSubmitting = true
        message = nil
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let api = HMRCBusinessAPI()
            let taxYear = HMRCDate.taxYear(containing: draft.periodEndDate)
            let result: HMRCPutCumulativeSummaryResult
            switch mode {
            case .consolidated:
                var input = draft.consolidatedInput()
                input["periodExpenses"] = ["consolidatedExpenses": max(consolidatedExpenseAmount, 0)]
                result = try await api.putSelfEmploymentCumulativeSummaryConsolidated(
                    nino: business.nino,
                    businessID: business.businessID,
                    taxYear: taxYear,
                    summary: input
                )
            case .nonConsolidated:
                result = try await api.putSelfEmploymentCumulativeSummaryNonConsolidated(
                    nino: business.nino,
                    businessID: business.businessID,
                    taxYear: taxYear,
                    summary: draft.nonConsolidatedInput()
                )
            }
            guard result.success else {
                if let error = result.error { throw error }
                throw SubmissionError.missingResponse
            }
            message = result.data?.correlationId.map { "Accepted by HMRC. Reference: \($0)" } ?? "Accepted by HMRC."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum SubmissionMode {
    case consolidated
    case nonConsolidated

    var title: String {
        switch self {
        case .consolidated: "consolidated summary"
        case .nonConsolidated: "non-consolidated summary"
        }
    }
}

private enum SubmissionError: LocalizedError {
    case missingResponse
    var errorDescription: String? { "The backend returned neither a submission result nor an error." }
}
