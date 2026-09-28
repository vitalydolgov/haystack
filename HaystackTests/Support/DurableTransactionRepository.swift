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

    func find(id: UUID) async -> Transaction? {
        await unitOfWork.store.transactions.find(id: id)
    }

    func findTransfer(id: UUID) async -> (Transaction, Transaction)? {
        await unitOfWork.store.transactions.findTransfer(id: id)
    }

    func find(accountID: UUID) async -> [Transaction] {
        await unitOfWork.store.transactions.find(accountID: accountID)
    }

    func delete(_ transaction: DeletedTransaction) async throws {
        try await unitOfWork.perform { try await $0.transactions.delete(transaction) }
    }
}
