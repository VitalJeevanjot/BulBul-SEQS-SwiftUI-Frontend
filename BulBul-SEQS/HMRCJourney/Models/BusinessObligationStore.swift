import Foundation
import SwiftData

enum BusinessObligationStore {
    @MainActor
    static func refresh(
        business: StoredBusiness,
        modelContext: ModelContext,
        api: any HMRCBusinessAPIProtocol = HMRCBusinessAPI()
    ) async throws {
        let result = try await api.retrieveIncomeAndExpenditureObligations(
            nino: business.nino,
            typeOfBusiness: business.typeOfBusiness,
            businessID: business.businessID,
            fromDate: nil,
            toDate: nil,
            status: nil
        )
        guard result.success else {
            if let error = result.error { throw error }
            throw BusinessObligationStoreError.missingResponse
        }

        for obligation in Array(business.obligations) {
            modelContext.delete(obligation)
        }

        let groups = result.data?.obligations ?? []
        for group in groups where group.businessId.caseInsensitiveCompare(business.businessID) == .orderedSame {
            for detail in group.obligationDetails ?? [] {
                modelContext.insert(
                    StoredObligation(
                        typeOfBusiness: group.typeOfBusiness,
                        businessID: group.businessId,
                        detail: detail,
                        business: business
                    )
                )
            }
        }
        business.obligationsFetchedAt = Date()
        business.updatedAt = Date()
        try modelContext.save()
    }
}

private enum BusinessObligationStoreError: LocalizedError {
    case missingResponse

    var errorDescription: String? {
        "HMRC returned neither obligations nor an error."
    }
}
