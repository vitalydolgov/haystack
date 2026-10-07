import Foundation
import SwiftData

actor SwiftDataTransactionRepository: TransactionRepository, ModelActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor

    init(modelContainer: ModelContainer, modelExecutor: any ModelExecutor) {
        self.modelContainer = modelContainer
        self.modelExecutor = modelExecutor
    }

    func save(_ transaction: Transaction) throws {
        if let record = record(id: transaction.id) {
            guard record.deletedAt == nil else { return }
            record.update(from: transaction)
        } else {
            modelContext.insert(TransactionRecord(transaction))
        }
    }

    func save(batch: [Transaction]) throws {
        for transaction in batch {
            try save(transaction)
        }
    }

    func query(id: UUID) throws -> Transaction? {
        let transactionID = id
        var descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.id == transactionID && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        guard let record = try modelContext.fetch(descriptor).first else { return nil }
        return try record.toTransaction()
    }

    func query(_ query: TransactionQuery) throws -> [Transaction] {
        try modelContext.fetch(descriptor(for: query)).map { try $0.toTransaction() }
    }

    func queryTransfer(id: UUID) throws -> (Transaction, Transaction)? {
        let transferID = id
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.transferID == transferID && $0.deletedAt == nil }
        )
        let transactions = try modelContext.fetch(descriptor).map { try $0.toTransaction() }
        guard transactions.count == 2,
              let outflow = transactions.first(where: { $0.amount < 0 }),
              let inflow = transactions.first(where: { $0.amount > 0 }) else {
            return nil
        }
        return (outflow, inflow)
    }

    func queryCounterpart(transactionID: UUID) async throws -> Transaction? {
        guard let transaction = try query(id: transactionID),
              let transferID = transaction.type.transferID,
              let (leg, counterpartLeg) = try await queryTransfer(id: transferID, relativeTo: transaction.accountID),
              leg.id == transaction.id else { return nil }
        return counterpartLeg
    }

    func querySplit(id: UUID) throws -> (Transaction, [Transaction])? {
        let splitID = id
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.splitID == splitID && $0.deletedAt == nil }
        )
        let transactions = try modelContext.fetch(descriptor).map { try $0.toTransaction() }
        let totals = transactions.filter {
            if case .split = $0.type { true } else { false }
        }
        guard totals.count == 1, let total = totals.first else { return nil }
        let parts = transactions.filter {
            if case .splitPart = $0.type { true } else { false }
        }
        return (total, parts)
    }

    func delete(_ transaction: DeletedTransaction) throws {
        guard let record = record(id: transaction.id), record.deletedAt == nil else { return }
        record.deletedAt = transaction.deletedAt
    }

    func delete(batch: [DeletedTransaction]) throws {
        for transaction in batch {
            try delete(transaction)
        }
    }

    private func descriptor(for query: TransactionQuery) -> FetchDescriptor<TransactionRecord> {
        switch query {
        case .account(let accountID):
            let accountID = accountID
            return FetchDescriptor(
                predicate: #Predicate { $0.accountID == accountID && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.packedDate, order: .reverse)]
            )
        case .all:
            return FetchDescriptor(
                predicate: #Predicate { $0.deletedAt == nil }
            )
        }
    }

    private func record(id: UUID) -> TransactionRecord? {
        var descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
