import Foundation
import Testing
@testable import Haystack

struct MoveTransactionTests {
    @Test func persistsTheMovedTransaction() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let source = try Account.make(name: "Wallet")
        let target = try Account.make(name: "Savings", type: .savings)
        await accounts.save(source)
        await accounts.save(target)
        let transaction = try Transaction.make(
            accountID: source.id,
            date: (year: 2026, month: 8, day: 31),
            amount: -12.5,
            notes: "Coffee"
        )
        await transactions.save(transaction)

        try await MoveTransaction(accounts: accounts, transactions: transactions).execute(
            id: transaction.id,
            toAccountID: target.id
        )
        let stored = try #require(await transactions.find(id: transaction.id))

        #expect(stored.accountID == target.id)
        #expect(stored.date == (year: 2026, month: 8, day: 31))
        #expect(stored.amount == -12.5)
        #expect(stored.notes == "Coffee")
        #expect(stored.type == .standard)
        #expect(await transactions.find(accountID: source.id).isEmpty)
        #expect(await transactions.all().count == 1)
    }

    @Test func doesNotChangeWhenAlreadyOnTheTargetAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let account = try Account.make()
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id)
        await transactions.save(transaction)

        try await MoveTransaction(accounts: accounts, transactions: transactions).execute(
            id: transaction.id,
            toAccountID: account.id
        )
        let stored = try #require(await transactions.find(id: transaction.id))
        #expect(stored.accountID == account.id)
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        await #expect(throws: TransactionError.notFound) {
            try await MoveTransaction(accounts: accounts, transactions: transactions).execute(
                id: UUID(),
                toAccountID: UUID()
            )
        }
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let source = try Account.make()
        let target = try Account.make(name: "Savings")
        await accounts.save(source)
        await accounts.save(target)
        let transaction = try Transaction.make(accountID: source.id)
        await transactions.save(transaction)
        await transactions.delete(transaction.delete())

        await #expect(throws: TransactionError.notFound) {
            try await MoveTransaction(accounts: accounts, transactions: transactions).execute(
                id: transaction.id,
                toAccountID: target.id
            )
        }
        #expect(await transactions.find(id: transaction.id) == nil)
        #expect(await transactions.find(accountID: target.id).isEmpty)
    }

    @Test func failsWhenTheTargetIsMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let source = try Account.make()
        await accounts.save(source)
        let transaction = try Transaction.make(accountID: source.id)
        await transactions.save(transaction)

        await #expect(throws: AccountError.notFound) {
            try await MoveTransaction(accounts: accounts, transactions: transactions).execute(
                id: transaction.id,
                toAccountID: UUID()
            )
        }
        let stored = try #require(await transactions.find(id: transaction.id))
        #expect(stored.accountID == source.id)
    }

    @Test func failsWhenTheTargetIsDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let source = try Account.make()
        let target = try Account.make(name: "Savings", type: .savings, isClosed: true)
        await accounts.save(source)
        await accounts.save(target)
        let transaction = try Transaction.make(accountID: source.id)
        await transactions.save(transaction)
        await accounts.delete(try target.delete())

        await #expect(throws: AccountError.notFound) {
            try await MoveTransaction(accounts: accounts, transactions: transactions).execute(
                id: transaction.id,
                toAccountID: target.id
            )
        }
        let stored = try #require(await transactions.find(id: transaction.id))
        #expect(stored.accountID == source.id)
    }

    @Test func failsWhenTheTargetIsClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let source = try Account.make()
        let target = try Account.make(name: "Savings", type: .savings, isClosed: true)
        await accounts.save(source)
        await accounts.save(target)
        let transaction = try Transaction.make(accountID: source.id)
        await transactions.save(transaction)

        await #expect(throws: AccountError.closed) {
            try await MoveTransaction(accounts: accounts, transactions: transactions).execute(
                id: transaction.id,
                toAccountID: target.id
            )
        }
        let stored = try #require(await transactions.find(id: transaction.id))
        #expect(stored.accountID == source.id)
    }
}
