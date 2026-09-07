import Foundation
import SwiftData

actor SwiftDataTransactionRepository: TransactionRepository, ModelActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let modelContext = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
    }

    func save(_ transaction: Transaction) throws {
        if let record = record(id: transaction.id) {
            guard record.deletedAt == nil else { return }
            record.update(from: transaction)
        } else {
            modelContext.insert(TransactionRecord(transaction))
        }
        try modelContext.save()
    }

    func find(id: UUID) -> Transaction? {
        guard let record = record(id: id), record.deletedAt == nil else { return nil }
        return try? record.toTransaction()
    }

    func find(accountID: UUID) -> [Transaction] {
        let accountID = accountID
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.accountID == accountID && $0.deletedAt == nil }
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).compactMap { try? $0.toTransaction() }
    }

    func delete(_ transaction: DeletedTransaction) throws {
        guard let record = record(id: transaction.id), record.deletedAt == nil else { return }
        record.deletedAt = transaction.deletedAt
        try modelContext.save()
    }

    private func record(id: UUID) -> TransactionRecord? {
        var descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
