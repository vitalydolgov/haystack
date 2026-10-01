import Foundation
import Testing
@testable import Haystack

struct DeleteTransactionTests {
    @Test func marksATransactionDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id)
        await transactions.save(transaction)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await DeleteTransaction(unitOfWork: unitOfWork).execute(id: transaction.id, at: deletedAt)
        #expect(await transactions.query(id: transaction.id) == nil)

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
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id)
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
        let fromLeg = try Transaction.make(amount: -10, type: .transfer(transferID))
        let toLeg = try Transaction.make(amount: 10, type: .transfer(transferID))
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: TransactionError.notFound) {
            try await DeleteTransaction(unitOfWork: unitOfWork).execute(id: fromLeg.id)
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
    }
}
