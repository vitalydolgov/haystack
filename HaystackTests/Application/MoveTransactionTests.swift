import Foundation
import Testing
@testable import Haystack

struct MoveTransactionTests {
    @Test func persistsTheMovedTransaction() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
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

        try await MoveTransaction(unitOfWork: unitOfWork).execute(
            id: transaction.id,
            movingTo: target.id
        )
        let stored = try #require(await transactions.query(id: transaction.id))

        #expect(stored.accountID == target.id)
        #expect(stored.date == (year: 2026, month: 8, day: 31))
        #expect(stored.amount == -12.5)
        #expect(stored.notes == "Coffee")
        #expect(stored.type == .standard)
        #expect(await transactions.query(.account(source.id)).isEmpty)
        #expect(await transactions.all().count == 1)
    }

    @Test func doesNotChangeWhenAlreadyOnTheTargetAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id)
        await transactions.save(transaction)

        try await MoveTransaction(unitOfWork: unitOfWork).execute(
            id: transaction.id,
            movingTo: account.id
        )
        let stored = try #require(await transactions.query(id: transaction.id))
        #expect(stored.accountID == account.id)
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        await #expect(throws: TransactionError.notFound) {
            try await MoveTransaction(unitOfWork: unitOfWork).execute(
                id: UUID(),
                movingTo: UUID()
            )
        }
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let source = try Account.make()
        let target = try Account.make(name: "Savings")
        await accounts.save(source)
        await accounts.save(target)
        let transaction = try Transaction.make(accountID: source.id)
        await transactions.save(transaction)
        await transactions.delete(transaction.delete())

        await #expect(throws: TransactionError.notFound) {
            try await MoveTransaction(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                movingTo: target.id
            )
        }
        #expect(await transactions.query(id: transaction.id) == nil)
        #expect(await transactions.query(.account(target.id)).isEmpty)
    }

    @Test func failsWhenTheTargetIsMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let source = try Account.make()
        await accounts.save(source)
        let transaction = try Transaction.make(accountID: source.id)
        await transactions.save(transaction)

        await #expect(throws: AccountError.notFound) {
            try await MoveTransaction(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                movingTo: UUID()
            )
        }
        let stored = try #require(await transactions.query(id: transaction.id))
        #expect(stored.accountID == source.id)
    }

    @Test func failsWhenTheTargetIsDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let source = try Account.make()
        let target = try Account.make(name: "Savings", type: .savings, isClosed: true)
        await accounts.save(source)
        await accounts.save(target)
        let transaction = try Transaction.make(accountID: source.id)
        await transactions.save(transaction)
        await accounts.delete(try target.delete())

        await #expect(throws: AccountError.notFound) {
            try await MoveTransaction(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                movingTo: target.id
            )
        }
        let stored = try #require(await transactions.query(id: transaction.id))
        #expect(stored.accountID == source.id)
    }

    @Test func failsWhenTheTargetIsClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let source = try Account.make()
        let target = try Account.make(name: "Savings", type: .savings, isClosed: true)
        await accounts.save(source)
        await accounts.save(target)
        let transaction = try Transaction.make(accountID: source.id)
        await transactions.save(transaction)

        await #expect(throws: AccountError.closed) {
            try await MoveTransaction(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                movingTo: target.id
            )
        }
        let stored = try #require(await transactions.query(id: transaction.id))
        #expect(stored.accountID == source.id)
    }

    @Test func failsWhenTransfer() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let source = try Account.make()
        let counterpart = try Account.make(name: "Savings", type: .savings)
        let target = try Account.make(name: "Credit")
        await accounts.save(source)
        await accounts.save(counterpart)
        await accounts.save(target)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: source.id,
            amount: -10,
            type: .transfer,
            transferID: transferID
        )
        let toLeg = try Transaction.make(
            accountID: counterpart.id,
            amount: 10,
            type: .transfer,
            transferID: transferID
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: TransactionError.invalidType) {
            try await MoveTransaction(unitOfWork: unitOfWork).execute(
                id: fromLeg.id,
                movingTo: target.id
            )
        }
        #expect(await transactions.query(id: fromLeg.id)?.accountID == source.id)
        #expect(await transactions.query(id: toLeg.id)?.accountID == counterpart.id)
    }
}
