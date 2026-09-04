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
