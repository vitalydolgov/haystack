import Foundation
import Testing
@testable import Haystack

struct EditTransactionTests {
    @Test func persistsDateAmountAndNotes() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(balance: 10)
        await accounts.save(account)
        let transaction = try Transaction.make(
            accountID: account.id,
            date: (year: 2026, month: 8, day: 31),
            amount: 10
        )
        await transactions.save(transaction)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try await EditTransaction(unitOfWork: unitOfWork).execute(
            id: transaction.id,
            accountID: account.id,
            date: date,
            amount: -12.5,
            notes: "Coffee"
        )
        let stored = try #require(await transactions.query(id: transaction.id))
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)

        #expect(stored.date == (year: components.year!, month: components.month!, day: components.day!))
        #expect(stored.amount == -12.5)
        #expect(stored.notes == "Coffee")
        #expect(try await accounts.query(id: account.id)?.balance == -12.5)
    }

    @Test func movesOntoAnotherAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let source = try Account.make(name: "Wallet", balance: -12.5)
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
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try await EditTransaction(unitOfWork: unitOfWork).execute(
            id: transaction.id,
            accountID: target.id,
            date: date,
            amount: -20,
            notes: "Lunch"
        )
        let stored = try #require(await transactions.query(id: transaction.id))
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)

        #expect(stored.accountID == target.id)
        #expect(stored.date == (year: components.year!, month: components.month!, day: components.day!))
        #expect(stored.amount == -20)
        #expect(stored.notes == "Lunch")
        #expect(await transactions.query(.account(source.id)).isEmpty)
        #expect(try await accounts.query(id: source.id)?.balance == 0)
        #expect(try await accounts.query(id: target.id)?.balance == -20)
    }

    // MARK: Can execute

    @Test func failsWhenAmountIsZero() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(balance: 10)
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id, amount: 10)
        await transactions.save(transaction)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await EditTransaction(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 0
            )
        }
        #expect(await transactions.query(id: transaction.id)?.amount == 10)
        #expect(try await accounts.query(id: account.id)?.balance == 10)
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        await #expect(throws: TransactionError.notFound) {
            try await EditTransaction(unitOfWork: unitOfWork).execute(
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
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id)
        await transactions.save(transaction)
        await transactions.delete(transaction.delete())

        await #expect(throws: TransactionError.notFound) {
            try await EditTransaction(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 20
            )
        }
        #expect(await transactions.query(id: transaction.id) == nil)
    }

    @Test func failsWhenTheAccountIsMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let accountID = UUID()
        let transaction = try Transaction.make(accountID: accountID)
        await transactions.save(transaction)

        await #expect(throws: AccountError.notFound) {
            try await EditTransaction(unitOfWork: unitOfWork).execute(
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
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id)
        await transactions.save(transaction)
        await accounts.delete(try account.delete())

        await #expect(throws: AccountError.notFound) {
            try await EditTransaction(unitOfWork: unitOfWork).execute(
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
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id)
        await transactions.save(transaction)

        await #expect(throws: AccountError.closed) {
            try await EditTransaction(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 20
            )
        }
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
            try await EditTransaction(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: UUID(),
                date: .now,
                amount: 20
            )
        }
        #expect(await transactions.query(id: transaction.id)?.accountID == source.id)
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
            try await EditTransaction(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: target.id,
                date: .now,
                amount: 20
            )
        }
        #expect(await transactions.query(id: transaction.id)?.accountID == source.id)
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
            try await EditTransaction(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: target.id,
                date: .now,
                amount: 20
            )
        }
        #expect(await transactions.query(id: transaction.id)?.accountID == source.id)
    }

    @Test func failsWhenTransfer() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: account.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(amount: 10, type: .transfer(transferID))
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: TransactionError.notFound) {
            try await EditTransaction(unitOfWork: unitOfWork).execute(
                id: fromLeg.id,
                accountID: account.id,
                date: .now,
                amount: -20
            )
        }
        #expect(await transactions.query(id: fromLeg.id)?.amount == -10)
        #expect(await transactions.query(id: toLeg.id)?.amount == 10)
    }

    @Test func failsWhenSplit() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(balance: 0)
        await accounts.save(account)
        let splitID = UUID()
        let total = try Transaction.make(
            id: splitID,
            accountID: account.id,
            amount: -30,
            type: .split(splitID)
        )
        await transactions.save(total)

        await #expect(throws: TransactionError.notFound) {
            try await EditTransaction(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: account.id,
                date: .now,
                amount: -20
            )
        }
        #expect(await transactions.query(id: total.id)?.amount == -30)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenSplitPart() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(balance: -10)
        await accounts.save(account)
        let splitID = UUID()
        let part = try Transaction.make(
            accountID: account.id,
            amount: -10,
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(part)

        await #expect(throws: TransactionError.notFound) {
            try await EditTransaction(unitOfWork: unitOfWork).execute(
                id: part.id,
                accountID: account.id,
                date: .now,
                amount: -20
            )
        }
        #expect(await transactions.query(id: part.id)?.amount == -10)
        #expect(try await accounts.query(id: account.id)?.balance == -10)
    }
}
