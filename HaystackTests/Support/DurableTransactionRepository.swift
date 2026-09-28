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

    func query(id: UUID) async throws -> Transaction? {
        try await unitOfWork.store.transactions.query(id: id)
    }

    func query(_ query: TransactionQuery) async throws -> [Transaction] {
        try await unitOfWork.store.transactions.query(query)
    }

    func queryTransfer(id: UUID) async throws -> (Transaction, Transaction)? {
        try await unitOfWork.store.transactions.queryTransfer(id: id)
    }

    func delete(_ transaction: DeletedTransaction) async throws {
        try await unitOfWork.perform { try await $0.transactions.delete(transaction) }
    }
}
