import SwiftData

enum LocalUserDataStore {
    @MainActor
    static func deleteAll(from modelContext: ModelContext) throws {
        do {
            try modelContext.delete(model: StoredBusiness.self)
            try modelContext.delete(model: HMRCUserProfile.self)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
