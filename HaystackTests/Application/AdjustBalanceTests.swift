import Foundation
import Testing
@testable import Haystack

struct AdjustBalanceTests {
    @Test func persistsNewBalance() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make()
        await accounts.save(account)

        try await AdjustBalance(accounts: accounts, transactions: transactions)
            .execute(id: account.id, to: 25)
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.balance(await transactions.find(accountID: stored.id)) == 25)
    }

    @Test func recordsAnAdjustment() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make()
        await accounts.save(account)

        try await AdjustBalance(accounts: accounts, transactions: transactions)
            .execute(id: account.id, to: 25)

        let recorded = await transactions.find(accountID: account.id)
        #expect(recorded.map(\.type) == [.adjustment])
    }

    @Test func doesNotRecordAnAdjustmentWhenAlreadyAtTarget() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make()
        await accounts.save(account)
        await transactions.save(try Transaction.make(accountID: account.id, amount: 25))

        try await AdjustBalance(accounts: accounts, transactions: transactions)
            .execute(id: account.id, to: 25)

        let recorded = await transactions.find(accountID: account.id)
        #expect(recorded.count == 1)
        #expect(recorded.map(\.type) == [.standard])
    }

    // MARK: Errors

    @Test func failsWhenClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)

        await #expect(throws: AccountError.closed) {
            try await AdjustBalance(accounts: accounts, transactions: transactions)
                .execute(id: account.id, to: 10)
        }
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.balance(await transactions.find(accountID: stored.id)) == 0)
    }

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        await #expect(throws: AccountError.notFound) {
            try await AdjustBalance(accounts: accounts, transactions: transactions)
                .execute(id: UUID(), to: 0)
        }
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let deleted = try account.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        await accounts.delete(deleted)

        await #expect(throws: AccountError.notFound) {
            try await AdjustBalance(accounts: accounts, transactions: transactions)
                .execute(id: account.id, to: 10)
        }
    }
}
