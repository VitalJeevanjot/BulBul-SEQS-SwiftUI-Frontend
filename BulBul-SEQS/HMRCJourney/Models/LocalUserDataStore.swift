import SwiftData

enum LocalUserDataStore {
    @MainActor
    static func deleteAllBusinesses(from modelContext: ModelContext) throws {
        do {
            try deleteAllBusinessModels(from: modelContext)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @MainActor
    static func deleteAll(from modelContext: ModelContext) throws {
        do {
            try deleteAllBusinessModels(from: modelContext)
            try modelContext.delete(model: HMRCUserProfile.self)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @MainActor
    private static func deleteAllBusinessModels(from modelContext: ModelContext) throws {
        let storedBusinesses = try modelContext.fetch(FetchDescriptor<StoredBusiness>())
        for business in storedBusinesses {
            modelContext.delete(business)
        }
    }
}
