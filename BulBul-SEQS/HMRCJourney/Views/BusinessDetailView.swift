import SwiftData
import SwiftUI

struct BusinessDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let business: StoredBusiness

    @State private var isRefreshing = false
    @State private var refreshMessage: String?
    @State private var refreshIssue: HMRCJourneyIssue?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard

                refreshCard

                if let refreshIssue {
                    HMRCIssueCard(issue: refreshIssue)
                }

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
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color.primary.opacity(0.025))
        .navigationTitle(business.tradingName ?? "Business details")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var refreshCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Task { await refreshBusinessDetails() }
            } label: {
                HStack(spacing: 10) {
                    if isRefreshing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }

                    Text(isRefreshing ? "Updating from HMRC…" : "Update business details")
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
                Label(refreshMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if let fetchedAt = business.fetchedAt {
                Text("Last updated \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.hmrcCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.1))
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)

            Text(business.tradingName ?? "HMRC Business")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text(business.businessID)
                .font(.subheadline.monospaced().weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))

            Label(
                business.typeOfBusiness.replacingOccurrences(of: "-", with: " ").capitalized,
                systemImage: "briefcase.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Details need attention", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(business.lastErrorMessage ?? "The business was found, but its detailed HMRC information has not been retrieved yet. Try loading your businesses again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let code = business.lastErrorCode {
                Text(code)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.orange)
            }
            if let reference = business.lastErrorCorrelationID {
                Text("Reference: \(reference)")
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
            }
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
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.indigo)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.hmrcCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.1))
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
        }
    }

    @MainActor
    private func refreshBusinessDetails() async {
        isRefreshing = true
        refreshMessage = nil
        refreshIssue = nil

        do {
            let result = try await HMRCBusinessAPI().retrieveBusinessDetails(
                nino: business.nino,
                businessID: business.businessID
            )

            guard result.success else {
                if let apiError = result.error {
                    business.update(error: apiError)
                    try? modelContext.save()
                    refreshIssue = HMRCJourneyIssue(
                        title: "HMRC could not update this business",
                        apiError: apiError
                    )
                    isRefreshing = false
                    return
                }
                throw BusinessRefreshError.missingResponse
            }

            guard let details = result.data else {
                throw BusinessRefreshError.missingResponse
            }
            guard HMRCIdentifierValidator.isValidBusinessID(details.businessId),
                  details.businessId == business.businessID else {
                throw BusinessRefreshError.mismatchedBusinessID(details.businessId)
            }

            business.update(details: details)
            try modelContext.save()
            refreshMessage = "Business details updated and saved."
            print("[HMRC] Replaced cached details for business \(business.businessID).")
        } catch let apiError as HMRCAPIError {
            business.update(error: apiError)
            try? modelContext.save()
            refreshIssue = HMRCJourneyIssue(
                title: "HMRC could not update this business",
                apiError: apiError
            )
        } catch {
            refreshIssue = HMRCJourneyIssue(
                title: "Could not update this business",
                message: error.localizedDescription
            )
        }

        isRefreshing = false
    }
}

private enum BusinessRefreshError: LocalizedError {
    case missingResponse
    case mismatchedBusinessID(String)

    var errorDescription: String? {
        switch self {
        case .missingResponse:
            return "HMRC returned neither updated business details nor an error."
        case .mismatchedBusinessID(let businessID):
            return "HMRC returned unexpected business ID \(businessID), so the saved details were not replaced."
        }
    }
}
