import Foundation
import Testing
@testable import Haystack

struct DeleteTransactionTests {
    @Test func marksATransactionDeleted() async throws {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)
        let transaction = try Transaction.make()
        await transactions.save(transaction)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await DeleteTransaction(unitOfWork: unitOfWork).execute(id: transaction.id, at: deletedAt)
        #expect(await transactions.find(id: transaction.id) == nil)

        let stored = try #require(await transactions.deleted(id: transaction.id))
        #expect(stored.deletedAt == deletedAt)
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)
        await #expect(throws: TransactionError.notFound) {
            try await DeleteTransaction(unitOfWork: unitOfWork).execute(id: UUID())
        }
    }

    @Test func failsWhenAlreadyDeleted() async throws {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)
        let transaction = try Transaction.make()
        await transactions.save(transaction)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try await DeleteTransaction(unitOfWork: unitOfWork).execute(id: transaction.id, at: deletedAt)

        await #expect(throws: TransactionError.notFound) {
            try await DeleteTransaction(unitOfWork: unitOfWork).execute(id: transaction.id)
        }
        let stored = try #require(await transactions.deleted(id: transaction.id))
        #expect(stored.deletedAt == deletedAt)
    }

    @Test func failsWhenTransfer() async throws {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)
        let transferID = UUID()
        let fromLeg = try Transaction.make(amount: -10, type: .transfer, transferID: transferID)
        let toLeg = try Transaction.make(amount: 10, type: .transfer, transferID: transferID)
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: TransactionError.invalidType) {
            try await DeleteTransaction(unitOfWork: unitOfWork).execute(id: fromLeg.id)
        }
        #expect(await transactions.find(id: fromLeg.id) != nil)
        #expect(await transactions.find(id: toLeg.id) != nil)
    }
}
