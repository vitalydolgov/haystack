import Foundation
import Testing
@testable import Haystack

struct DeleteTransactionTests {
    @Test func marksATransactionDeleted() async throws {
        let transactions = InMemoryTransactionRepository()
        let transaction = try Transaction.make()
        await transactions.save(transaction)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await DeleteTransaction(transactions: transactions).execute(id: transaction.id, at: deletedAt)
        #expect(await transactions.find(id: transaction.id) == nil)

        let stored = try #require(await transactions.deleted(id: transaction.id))
        #expect(stored.deletedAt == deletedAt)
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let transactions = InMemoryTransactionRepository()
        await #expect(throws: TransactionError.notFound) {
            try await DeleteTransaction(transactions: transactions).execute(id: UUID())
        }
    }

    @Test func failsWhenAlreadyDeleted() async throws {
        let transactions = InMemoryTransactionRepository()
        let transaction = try Transaction.make()
        await transactions.save(transaction)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try await DeleteTransaction(transactions: transactions).execute(id: transaction.id, at: deletedAt)

        await #expect(throws: TransactionError.notFound) {
            try await DeleteTransaction(transactions: transactions).execute(id: transaction.id)
        }
        let stored = try #require(await transactions.deleted(id: transaction.id))
        #expect(stored.deletedAt == deletedAt)
    }
}
