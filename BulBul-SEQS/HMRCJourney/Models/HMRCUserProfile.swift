import Foundation
import SwiftData

@Model
final class HMRCUserProfile {
    var recordID: UUID = UUID()
    var userID: String = ""
    var email: String?
    var nino: String?
    var updatedAt: Date = Date()

    init(userID: String, email: String? = nil, nino: String? = nil) {
        self.userID = userID
        self.email = email
        self.nino = nino
    }
}
