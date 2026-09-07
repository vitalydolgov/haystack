import Foundation
import SwiftData

actor SwiftDataUnitOfWork: UnitOfWork, ModelActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let accounts: any AccountRepository
    nonisolated let transactions: any TransactionRepository

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
        let modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
        self.modelExecutor = modelExecutor
        self.accounts = SwiftDataAccountRepository(modelContainer: modelContainer, modelExecutor: modelExecutor)
        self.transactions = SwiftDataTransactionRepository(modelContainer: modelContainer, modelExecutor: modelExecutor)
    }

    func perform<T: Sendable>(_ work: @Sendable () async throws -> T) async throws -> T {
        do {
            let result = try await work()
            if modelContext.hasChanges { try modelContext.save() }
            return result
        } catch {
            if modelContext.hasChanges { modelContext.rollback() }
            throw error
        }
    }
}
