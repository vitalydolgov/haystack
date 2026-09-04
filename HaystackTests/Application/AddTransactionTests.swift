import Foundation
import Testing
@testable import Haystack

struct AddTransactionTests {
    @Test func persistsTheTransaction() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make()
        await accounts.save(account)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let added = try await AddTransaction(accounts: accounts, transactions: transactions).execute(
            accountID: account.id,
            date: date,
            amount: -12.5,
            notes: "Coffee"
        )
        let stored = try #require(await transactions.find(id: added.id))
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)

        #expect(stored.accountID == account.id)
        #expect(stored.date == (year: components.year!, month: components.month!, day: components.day!))
        #expect(stored.amount == -12.5)
        #expect(stored.notes == "Coffee")
        #expect(stored.type == .standard)
    }

    // MARK: Validation

    @Test func allowsSaveWhenAmountIsNonZero() {
        #expect(AddTransaction.canExecute(accountID: UUID(), amount: 1, date: .now))
    }

    @Test func doesNotAllowSaveWhenAmountIsZero() {
        #expect(!AddTransaction.canExecute(accountID: UUID(), amount: 0, date: .now))
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        await #expect(throws: AccountError.notFound) {
            try await AddTransaction(accounts: accounts, transactions: transactions).execute(
                accountID: UUID(),
                amount: 10
            )
        }
        #expect(await transactions.all().isEmpty)
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        await accounts.delete(try account.delete())

        await #expect(throws: AccountError.notFound) {
            try await AddTransaction(accounts: accounts, transactions: transactions).execute(
                accountID: account.id,
                amount: 10
            )
        }
        #expect(await transactions.all().isEmpty)
    }

    @Test func failsWhenClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)

        await #expect(throws: AccountError.closed) {
            try await AddTransaction(accounts: accounts, transactions: transactions).execute(
                accountID: account.id,
                amount: 10
            )
        }
        #expect(await transactions.all().isEmpty)
    }
}
