import Amplify
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class HMRCJourneyViewModel {
    var profile: HMRCUserProfile?
    var businesses: [StoredBusiness] = []
    var ninoInput = ""
    var isLoading = false
    var progressMessage: String?
    var successMessage: String?
    var issues: [HMRCJourneyIssue] = []

    private let api: any HMRCBusinessAPIProtocol
    private var hasLoaded = false

    init(api: any HMRCBusinessAPIProtocol = HMRCBusinessAPI()) {
        self.api = api
    }

    var isNINOValid: Bool {
        HMRCIdentifierValidator.isValidNINO(ninoInput)
    }

    var userDisplayName: String {
        profile?.email ?? "Signed-in user"
    }

    func updateNINOInput(_ value: String) {
        ninoInput = HMRCIdentifierValidator.normalizedNINO(value)
    }

    func load(modelContext: ModelContext) async {
        guard !hasLoaded else { return }
        hasLoaded = true

        do {
            let authUser = try await Amplify.Auth.getCurrentUser()
            let userID = authUser.userId
            let email = await currentUserEmail()

            let storedProfiles = try modelContext.fetch(FetchDescriptor<HMRCUserProfile>())
            let storedProfile = storedProfiles.first { $0.userID == userID }

            for obsoleteProfile in storedProfiles where obsoleteProfile !== storedProfile {
                modelContext.delete(obsoleteProfile)
            }

            let storedBusinesses = try modelContext.fetch(FetchDescriptor<StoredBusiness>())
            for obsoleteBusiness in storedBusinesses where obsoleteBusiness.userID != userID {
                modelContext.delete(obsoleteBusiness)
            }

            if let storedProfile {
                profile = storedProfile
                storedProfile.email = email ?? storedProfile.email
                storedProfile.updatedAt = Date()
            } else {
                let newProfile = HMRCUserProfile(
                    userID: userID,
                    email: email
                )
                modelContext.insert(newProfile)
                profile = newProfile
            }

            if let storedNINO = profile?.nino {
                ninoInput = storedNINO
            }

            try modelContext.save()
            try loadStoredBusinesses(modelContext: modelContext)
        } catch {
            issues = [
                HMRCJourneyIssue(
                    title: "Could not load your profile",
                    message: error.localizedDescription
                )
            ]
        }
    }

    func getBusinesses(modelContext: ModelContext) async {
        let nino = HMRCIdentifierValidator.normalizedNINO(ninoInput)
        guard HMRCIdentifierValidator.isValidNINO(nino) else {
            issues = [
                HMRCJourneyIssue(
                    title: "Check your National Insurance number",
                    message: "Enter a valid NINO using two letters, six digits and a final letter from A to D."
                )
            ]
            return
        }
        guard let profile else {
            issues = [
                HMRCJourneyIssue(
                    title: "Profile unavailable",
                    message: "Your signed-in profile has not finished loading. Please try again."
                )
            ]
            return
        }

        isLoading = true
        issues = []
        successMessage = nil
        ninoInput = nino

        do {
            progressMessage = "Asking HMRC for your businesses…"
            let result = try await api.listBusinesses(nino: nino)

            guard result.success else {
                if let apiError = result.error {
                    throw apiError
                }
                throw JourneyError.emptyAPIResponse("HMRC did not return business data or an error.")
            }

            profile.nino = nino
            profile.updatedAt = Date()
            try modelContext.save()

            let summaries = result.data?.listOfBusinesses ?? []
            let validSummaries = validatedUniqueSummaries(summaries)
            print("[HMRC] Extracted business IDs: \(validSummaries.map(\.businessId))")

            try loadStoredBusinesses(modelContext: modelContext)
            var storedByID = Dictionary(uniqueKeysWithValues: businesses.map { ($0.businessID, $0) })

            for summary in validSummaries {
                if let stored = storedByID[summary.businessId] {
                    stored.update(summary: summary)
                } else {
                    let stored = StoredBusiness(userID: profile.userID, nino: nino, summary: summary)
                    modelContext.insert(stored)
                    storedByID[summary.businessId] = stored
                }
            }

            try modelContext.save()

            for (index, summary) in validSummaries.enumerated() {
                guard let stored = storedByID[summary.businessId] else { continue }
                guard !stored.hasDetails else {
                    print("[HMRC] Cache hit for business \(summary.businessId); details request skipped.")
                    continue
                }

                progressMessage = "Loading business \(index + 1) of \(validSummaries.count)…"
                await retrieveAndStoreDetails(
                    nino: nino,
                    summary: summary,
                    stored: stored,
                    modelContext: modelContext
                )
            }

            try loadStoredBusinesses(modelContext: modelContext)
            successMessage = validSummaries.isEmpty
                ? "HMRC returned no businesses for this NINO."
                : "Loaded \(validSummaries.count) business\(validSummaries.count == 1 ? "" : "es"). Saved details are reused from SwiftData."
            print("[HMRC] Stored businesses: \(businesses.map { "\($0.businessID): details=\($0.hasDetails)" })")
        } catch let apiError as HMRCAPIError {
            issues.append(
                HMRCJourneyIssue(
                    title: "HMRC could not verify or load this NINO",
                    message: "\(apiError.message) Check the NINO is correct, or re-sign in with the HMRC account linked to it.",
                    code: apiError.code,
                    statusCode: apiError.statusCode,
                    correlationID: apiError.correlationId
                )
            )
            try? loadStoredBusinesses(modelContext: modelContext)
        } catch {
            issues.append(
                HMRCJourneyIssue(
                    title: "Could not load businesses",
                    message: error.localizedDescription
                )
            )
            try? loadStoredBusinesses(modelContext: modelContext)
        }

        progressMessage = nil
        isLoading = false
    }

    private func validatedUniqueSummaries(
        _ summaries: [HMRCBusinessSummary]
    ) -> [HMRCBusinessSummary] {
        var seen = Set<String>()

        return summaries.compactMap { summary in
            let businessID = summary.businessId.uppercased()
            guard HMRCIdentifierValidator.isValidBusinessID(businessID) else {
                issues.append(
                    HMRCJourneyIssue(
                        title: "HMRC returned an invalid business ID",
                        message: "The value \(summary.businessId) was excluded because it did not match the required business ID format."
                    )
                )
                return nil
            }
            guard seen.insert(businessID).inserted else { return nil }

            return HMRCBusinessSummary(
                typeOfBusiness: summary.typeOfBusiness,
                businessId: businessID,
                tradingName: summary.tradingName
            )
        }
    }

    private func retrieveAndStoreDetails(
        nino: String,
        summary: HMRCBusinessSummary,
        stored: StoredBusiness,
        modelContext: ModelContext
    ) async {
        do {
            let result = try await api.retrieveBusinessDetails(
                nino: nino,
                businessID: summary.businessId
            )

            if result.success, let details = result.data {
                guard HMRCIdentifierValidator.isValidBusinessID(details.businessId) else {
                    throw JourneyError.invalidBusinessID(details.businessId)
                }
                stored.update(details: details)
            } else if let apiError = result.error {
                stored.update(error: apiError)
                issues.append(
                    HMRCJourneyIssue(
                        title: "Could not load \(summary.businessId)",
                        apiError: apiError
                    )
                )
            } else {
                let message = "HMRC returned neither business details nor an error."
                stored.update(errorMessage: message)
                issues.append(HMRCJourneyIssue(title: "Could not load \(summary.businessId)", message: message))
            }
            try modelContext.save()
        } catch let apiError as HMRCAPIError {
            stored.update(error: apiError)
            issues.append(HMRCJourneyIssue(title: "Could not load \(summary.businessId)", apiError: apiError))
            try? modelContext.save()
        } catch {
            stored.update(errorMessage: error.localizedDescription)
            issues.append(
                HMRCJourneyIssue(
                    title: "Could not load \(summary.businessId)",
                    message: error.localizedDescription
                )
            )
            try? modelContext.save()
        }
    }

    private func loadStoredBusinesses(modelContext: ModelContext) throws {
        guard let profile else {
            businesses = []
            return
        }
        let userID = profile.userID
        let nino = profile.nino ?? ""
        let descriptor = FetchDescriptor<StoredBusiness>(
            predicate: #Predicate { $0.userID == userID && $0.nino == nino },
            sortBy: [SortDescriptor(\.tradingName), SortDescriptor(\.businessID)]
        )
        businesses = try modelContext.fetch(descriptor)
    }

    private func currentUserEmail() async -> String? {
        guard let attributes = try? await Amplify.Auth.fetchUserAttributes() else {
            return nil
        }
        return attributes.first { $0.key == .email }?.value
    }
}

private enum JourneyError: LocalizedError {
    case emptyAPIResponse(String)
    case invalidBusinessID(String)

    var errorDescription: String? {
        switch self {
        case .emptyAPIResponse(let message):
            return message
        case .invalidBusinessID(let businessID):
            return "HMRC returned invalid business ID \(businessID)."
        }
    }
}
