import Foundation
import Testing
@testable import Haystack

struct CloseAccountTests {
    @Test func zeroesBalanceThenCloses() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        await transactions.save(try Transaction.make(accountID: account.id, amount: 25))

        try await CloseAccount(unitOfWork: unitOfWork).execute(id: account.id)
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.balance(await transactions.find(accountID: stored.id)) == 0)
        #expect(stored.isClosed)
    }

    @Test func doesNotChangeAnAlreadyClosedAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)

        try await CloseAccount(unitOfWork: unitOfWork).execute(id: account.id)
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.isClosed)
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        await #expect(throws: AccountError.notFound) {
            try await CloseAccount(unitOfWork: unitOfWork).execute(id: UUID())
        }
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let deleted = try account.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        await accounts.delete(deleted)

        await #expect(throws: AccountError.notFound) {
            try await CloseAccount(unitOfWork: unitOfWork).execute(id: account.id)
        }
    }
}
