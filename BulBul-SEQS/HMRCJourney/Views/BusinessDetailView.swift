import SwiftData
import SwiftUI

struct BusinessDetailView: View {
    @Bindable var business: StoredBusiness

    var body: some View {
        VStack(spacing: 0) {
            BusinessIdentityHeader(business: business)
                .padding(.horizontal)
                .padding(.top, 10)

            TabView {
                Tab("Details", systemImage: "building.2") {
                    tabScrollView { BusinessDetailsTab(business: business) }
                }

                Tab("Digital Records", systemImage: "tablecells") {
                    tabScrollView(maxWidth: .infinity) { DigitalRecordsView(business: business) }
                }

                Tab("Obligations", systemImage: "calendar.badge.clock") {
                    tabScrollView(maxWidth: 1100) { ObligationsView(business: business) }
                }

                Tab("Cumulative", systemImage: "chart.bar.doc.horizontal") {
                    tabScrollView(maxWidth: 1000) { CumulativeSummaryView(business: business) }
                }
            }
        }
        .background(Color.primary.opacity(0.025))
        .navigationTitle(business.tradingName ?? "Business")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func tabScrollView<Content: View>(
        maxWidth: CGFloat = 800,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            content()
                .padding()
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct BusinessIdentityHeader: View {
    let business: StoredBusiness

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(business.tradingName ?? "HMRC Business")
                    .font(.title2.bold())
                    .lineLimit(1)
                Text(business.businessID)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Text(business.typeOfBusiness.replacingOccurrences(of: "-", with: " ").capitalized)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.indigo.opacity(0.1), in: Capsule())
        }
        .padding(14)
        .background(Color.hmrcCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.secondary.opacity(0.1)) }
    }
}

private struct BusinessDetailsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var business: StoredBusiness

    @State private var isRefreshing = false
    @State private var refreshMessage: String?
    @State private var refreshIssue: HMRCJourneyIssue?

    var body: some View {
        VStack(spacing: 18) {
            refreshCard

            if let refreshIssue { HMRCIssueCard(issue: refreshIssue) }

            if !business.hasDetails {
                unavailableCard
            } else {
                if !business.addressLines.isEmpty {
                    detailSection(title: "Business address", systemImage: "mappin.and.ellipse") {
                        Text(business.addressLines.joined(separator: "\n"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                detailSection(title: "Important dates", systemImage: "calendar") {
                    detailRow("Commencement", value: business.commencementDate)
                    detailRow("Cessation", value: business.cessationDate)
                    detailRow("First period starts", value: business.firstAccountingPeriodStartDate)
                    detailRow("First period ends", value: business.firstAccountingPeriodEndDate)
                    detailRow("Migration year", value: business.yearOfMigration)
                }

                if !business.accountingPeriods.isEmpty {
                    detailSection(title: "Accounting periods", systemImage: "calendar.badge.clock") {
                        ForEach(business.accountingPeriods) { period in
                            HStack {
                                Text(period.start)
                                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                                Text(period.end)
                                Spacer()
                            }
                            .font(.subheadline.monospacedDigit())
                        }
                    }
                }

                if let quarterly = business.quarterlyTypeChoice {
                    detailSection(title: "Quarterly reporting", systemImage: "chart.bar.doc.horizontal") {
                        detailRow("Period type", value: quarterly.quarterlyPeriodType)
                        detailRow("Tax year", value: quarterly.taxYearOfChoice)
                    }
                }

                if let latency = business.latencyDetails {
                    detailSection(title: "Latency details", systemImage: "clock.arrow.circlepath") {
                        detailRow("End date", value: latency.latencyEndDate)
                        detailRow(latency.taxYear1, value: latency.latencyIndicator1)
                        detailRow(latency.taxYear2, value: latency.latencyIndicator2)
                    }
                }
            }
        }
    }

    private var refreshCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Task { await refreshBusinessDetails() }
            } label: {
                HStack(spacing: 10) {
                    if isRefreshing { ProgressView().tint(.white) }
                    else { Image(systemName: "arrow.clockwise") }
                    Text(isRefreshing ? "Updating details and obligations…" : "Update business details")
                        .fontWeight(.bold)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(.indigo)
            .disabled(isRefreshing)
            .accessibilityIdentifier("update-business-details-button")

            if let refreshMessage {
                Label(refreshMessage, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
            } else if let fetchedAt = business.fetchedAt {
                Text("Last updated \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.hmrcCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.secondary.opacity(0.1)) }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Details need attention", systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(.orange)
            Text(business.lastErrorMessage ?? "The business was found, but its detailed HMRC information has not been retrieved yet.")
                .font(.subheadline).foregroundStyle(.secondary)
            if let code = business.lastErrorCode { Text(code).font(.caption.monospaced().weight(.semibold)).foregroundStyle(.orange) }
            if let reference = business.lastErrorCorrelationID { Text("Reference: \(reference)").font(.caption2.monospaced()).textSelection(.enabled) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
    }

    private func detailSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage).font(.headline).foregroundStyle(.indigo)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.hmrcCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.secondary.opacity(0.1)) }
    }

    @ViewBuilder
    private func detailRow(_ label: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
        }
    }

    @MainActor
    private func refreshBusinessDetails() async {
        isRefreshing = true
        refreshMessage = nil
        refreshIssue = nil
        defer { isRefreshing = false }

        do {
            let result = try await HMRCBusinessAPI().retrieveBusinessDetails(nino: business.nino, businessID: business.businessID)
            guard result.success else {
                if let apiError = result.error { throw apiError }
                throw BusinessRefreshError.missingResponse
            }
            guard let details = result.data else { throw BusinessRefreshError.missingResponse }
            guard HMRCIdentifierValidator.isValidBusinessID(details.businessId), details.businessId == business.businessID else {
                throw BusinessRefreshError.mismatchedBusinessID(details.businessId)
            }
            business.update(details: details)
            try modelContext.save()
            try await BusinessObligationStore.refresh(business: business, modelContext: modelContext)
            refreshMessage = "Business details and obligations updated and saved."
        } catch let apiError as HMRCAPIError {
            business.update(error: apiError)
            try? modelContext.save()
            refreshIssue = HMRCJourneyIssue(title: "HMRC could not update this business", apiError: apiError)
        } catch {
            refreshIssue = HMRCJourneyIssue(title: "Could not update this business", message: error.localizedDescription)
        }
    }
}

private enum BusinessRefreshError: LocalizedError {
    case missingResponse
    case mismatchedBusinessID(String)

    var errorDescription: String? {
        switch self {
        case .missingResponse: "HMRC returned neither updated business details nor an error."
        case .mismatchedBusinessID(let businessID): "HMRC returned unexpected business ID \(businessID), so the saved details were not replaced."
        }
    }
}
