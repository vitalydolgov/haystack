import Foundation
import SwiftData
@testable import Haystack

struct DurableTransactionRepository: TransactionRepository {
    let unitOfWork: SwiftDataUnitOfWork

    init(modelContainer: ModelContainer) {
        self.unitOfWork = SwiftDataUnitOfWork(modelContainer: modelContainer)
    }

    func save(_ transaction: Transaction) async throws {
        try await unitOfWork.perform { try await $0.transactions.save(transaction) }
    }

    func save(batch: [Transaction]) async throws {
        try await unitOfWork.perform { store in
            try await store.transactions.save(batch: batch)
        }
    }

    func query(id: UUID) async throws -> Transaction? {
        try await unitOfWork.store.transactions.query(id: id)
    }

    func query(_ query: TransactionQuery) async throws -> [Transaction] {
        try await unitOfWork.store.transactions.query(query)
    }

    func queryTransfer(id: UUID) async throws -> (Transaction, Transaction)? {
        try await unitOfWork.store.transactions.queryTransfer(id: id)
    }

    func queryCounterpart(transactionID: UUID) async throws -> Transaction? {
        try await unitOfWork.store.transactions.queryCounterpart(transactionID: transactionID)
    }

    func querySplit(id: UUID) async throws -> (Transaction, [Transaction])? {
        try await unitOfWork.store.transactions.querySplit(id: id)
    }

    func delete(_ transaction: DeletedTransaction) async throws {
        try await unitOfWork.perform { try await $0.transactions.delete(transaction) }
    }

    func delete(batch: [DeletedTransaction]) async throws {
        try await unitOfWork.perform { store in
            try await store.transactions.delete(batch: batch)
        }
    }
}
