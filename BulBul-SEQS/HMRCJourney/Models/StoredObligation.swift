import Foundation
import SwiftData

@Model
final class StoredObligation {
    var recordID: UUID = UUID()
    var typeOfBusiness: String = ""
    var businessID: String = ""
    var periodStartDate: String = ""
    var periodEndDate: String = ""
    var dueDate: String = ""
    var status: String = ""
    var receivedDate: String?
    var fetchedAt: Date = Date()
    var business: StoredBusiness?

    init(
        typeOfBusiness: String,
        businessID: String,
        detail: HMRCObligationDetail,
        business: StoredBusiness? = nil
    ) {
        self.typeOfBusiness = typeOfBusiness
        self.businessID = businessID
        periodStartDate = detail.periodStartDate
        periodEndDate = detail.periodEndDate
        dueDate = detail.dueDate
        status = detail.status
        receivedDate = detail.receivedDate
        self.business = business
    }

    var isSelfEmployment: Bool {
        typeOfBusiness.caseInsensitiveCompare("self-employment") == .orderedSame
    }

    var actionTitle: String? {
        guard isSelfEmployment else { return nil }
        switch status.lowercased() {
        case "fulfilled": return "Amend"
        case "open": return "Fulfill"
        default: return nil
        }
    }
}
