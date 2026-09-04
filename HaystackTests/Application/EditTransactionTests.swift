import Foundation
import Testing
@testable import Haystack

struct EditTransactionTests {
    @Test func persistsDateAmountAndNotes() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make()
        await accounts.save(account)
        let transaction = try Transaction.make(
            accountID: account.id,
            date: (year: 2026, month: 8, day: 31),
            amount: 10
        )
        await transactions.save(transaction)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try await EditTransaction(accounts: accounts, transactions: transactions).execute(
            id: transaction.id,
            accountID: account.id,
            date: date,
            amount: -12.5,
            notes: "Coffee"
        )
        let stored = try #require(await transactions.find(id: transaction.id))
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)

        #expect(stored.date == (year: components.year!, month: components.month!, day: components.day!))
        #expect(stored.amount == -12.5)
        #expect(stored.notes == "Coffee")
    }

    // MARK: Validation

    @Test func allowsSaveWhenAmountIsNonZero() {
        #expect(EditTransaction.canExecute(accountID: UUID(), amount: 1, date: .now))
    }

    @Test func doesNotAllowSaveWhenAmountIsZero() {
        #expect(!EditTransaction.canExecute(accountID: UUID(), amount: 0, date: .now))
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        await #expect(throws: TransactionError.notFound) {
            try await EditTransaction(accounts: accounts, transactions: transactions).execute(
                id: UUID(),
                accountID: UUID(),
                date: .now,
                amount: 10
            )
        }
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make()
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id)
        await transactions.save(transaction)
        await transactions.delete(transaction.delete())

        await #expect(throws: TransactionError.notFound) {
            try await EditTransaction(accounts: accounts, transactions: transactions).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 20
            )
        }
        #expect(await transactions.find(id: transaction.id) == nil)
    }

    @Test func failsWhenTheAccountDoesNotMatch() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make()
        let other = try Account.make(name: "Savings")
        await accounts.save(account)
        await accounts.save(other)
        let transaction = try Transaction.make(accountID: account.id)
        await transactions.save(transaction)

        await #expect(throws: TransactionError.notFound) {
            try await EditTransaction(accounts: accounts, transactions: transactions).execute(
                id: transaction.id,
                accountID: other.id,
                date: .now,
                amount: 20
            )
        }
        let stored = try #require(await transactions.find(id: transaction.id))
        #expect(stored.accountID == account.id)
    }

    @Test func failsWhenTheAccountIsMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let accountID = UUID()
        let transaction = try Transaction.make(accountID: accountID)
        await transactions.save(transaction)

        await #expect(throws: AccountError.notFound) {
            try await EditTransaction(accounts: accounts, transactions: transactions).execute(
                id: transaction.id,
                accountID: accountID,
                date: .now,
                amount: 20
            )
        }
    }

    @Test func failsWhenTheAccountIsDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id)
        await transactions.save(transaction)
        await accounts.delete(try account.delete())

        await #expect(throws: AccountError.notFound) {
            try await EditTransaction(accounts: accounts, transactions: transactions).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 20
            )
        }
    }

    @Test func failsWhenClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id)
        await transactions.save(transaction)

        await #expect(throws: AccountError.closed) {
            try await EditTransaction(accounts: accounts, transactions: transactions).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 20
            )
        }
    }
}
