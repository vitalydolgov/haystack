import Foundation
import SwiftData

actor SwiftDataUnitOfWork: UnitOfWork, ModelActor {
    @TaskLocal private static var isPerforming = false

    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let store: Store

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
        self.store = Store(
            accounts: SwiftDataAccountRepository(modelContainer: modelContainer, modelExecutor: modelExecutor),
            transactions: SwiftDataTransactionRepository(modelContainer: modelContainer, modelExecutor: modelExecutor)
        )
    }

    func perform<T: Sendable>(_ work: @Sendable (Store) async throws -> T) async throws -> T {
        if Self.isPerforming {  // nested call
            return try await work(store)
        }
        return try await Self.$isPerforming.withValue(true) {
            do {
                let result = try await work(store)
                if modelContext.hasChanges { try modelContext.save() }
                return result
            } catch {
                if modelContext.hasChanges { modelContext.rollback() }
                throw error
            }
        }
    }
}
