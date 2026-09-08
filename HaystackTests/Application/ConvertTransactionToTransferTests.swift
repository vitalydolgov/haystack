import Foundation
import Testing
@testable import Haystack

struct ConvertTransactionToTransferTests {
    @Test func convertsTransactionAndCreatesCounterpart() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(name: "Wallet")
        let counterpartAccount = try Account.make(name: "Savings", type: .savings)
        await accounts.save(account)
        await accounts.save(counterpartAccount)
        let transaction = try Transaction.make(
            accountID: account.id,
            date: (year: 2026, month: 8, day: 31),
            amount: 10,
            notes: "Lunch"
        )
        await transactions.save(transaction)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
            id: transaction.id,
            accountID: account.id,
            counterpartAccountID: counterpartAccount.id,
            date: date,
            amount: -12.5,
            notes: "Coffee"
        )

        let stored = try #require(await transactions.find(id: transaction.id))
        #expect(stored.accountID == account.id)
        #expect(stored.type == .transfer)
        #expect(stored.amount == -12.5)
        #expect(stored.notes == "Coffee")
        #expect(stored.date == date.asYearMonthDay())

        let transferID = try #require(stored.transferID)
        let counterpart = try #require(await transactions.all().first { $0.id != stored.id })
        #expect(counterpart.accountID == counterpartAccount.id)
        #expect(counterpart.type == .transfer)
        #expect(counterpart.transferID == transferID)
        #expect(counterpart.amount == 12.5)
        #expect(counterpart.notes == "Coffee")
        #expect(counterpart.date == date.asYearMonthDay())
        #expect(await transactions.all().count == 2)
    }

    @Test func convertsInflowTransaction() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(name: "Wallet")
        let counterpartAccount = try Account.make(name: "Savings", type: .savings)
        await accounts.save(account)
        await accounts.save(counterpartAccount)
        let transaction = try Transaction.make(accountID: account.id, amount: 10)
        await transactions.save(transaction)

        try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
            id: transaction.id,
            accountID: account.id,
            counterpartAccountID: counterpartAccount.id,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            amount: 12.5
        )

        let stored = try #require(await transactions.find(id: transaction.id))
        #expect(stored.amount == 12.5)
        let counterpart = try #require(await transactions.all().first { $0.id != stored.id })
        #expect(counterpart.accountID == counterpartAccount.id)
        #expect(counterpart.amount == -12.5)
    }

    @Test func movesTransactionWhenAccountDiffers() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(name: "Wallet")
        let targetAccount = try Account.make(name: "Checking", type: .debitCard)
        let counterpartAccount = try Account.make(name: "Savings", type: .savings)
        await accounts.save(account)
        await accounts.save(targetAccount)
        await accounts.save(counterpartAccount)
        let transaction = try Transaction.make(accountID: account.id, amount: 10)
        await transactions.save(transaction)

        try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
            id: transaction.id,
            accountID: targetAccount.id,
            counterpartAccountID: counterpartAccount.id,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            amount: -12.5
        )

        let stored = try #require(await transactions.find(id: transaction.id))
        #expect(stored.accountID == targetAccount.id)
        #expect(stored.type == .transfer)
        let counterpart = try #require(await transactions.all().first { $0.id != stored.id })
        #expect(counterpart.accountID == counterpartAccount.id)
        #expect(counterpart.transferID == stored.transferID)
    }

    // MARK: Errors

    @Test func failsWhenAccountsMatch() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id, amount: 10)
        await transactions.save(transaction)

        await #expect(throws: TransferError.sameAccount) {
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                counterpartAccountID: account.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -10
            )
        }
        #expect(await transactions.find(id: transaction.id)?.type == .standard)
        #expect(await transactions.all().count == 1)
    }

    @Test func failsWhenTransactionMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        let counterpartAccount = try Account.make(type: .savings)
        await accounts.save(account)
        await accounts.save(counterpartAccount)

        await #expect(throws: TransactionError.notFound) {
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: UUID(),
                accountID: account.id,
                counterpartAccountID: counterpartAccount.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -10
            )
        }
        #expect(await transactions.all().isEmpty)
    }

    @Test func failsWhenTransactionIsTransfer() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        let counterpartAccount = try Account.make(type: .savings)
        await accounts.save(account)
        await accounts.save(counterpartAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: account.id,
            amount: -10,
            type: .transfer,
            transferID: transferID
        )
        let toLeg = try Transaction.make(amount: 10, type: .transfer, transferID: transferID)
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: TransactionError.notFound) {
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: fromLeg.id,
                accountID: account.id,
                counterpartAccountID: counterpartAccount.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -10
            )
        }
        #expect(await transactions.find(id: fromLeg.id)?.transferID == transferID)
        #expect(await transactions.find(id: toLeg.id)?.transferID == transferID)
        #expect(await transactions.all().count == 2)
    }

    @Test func failsWhenAccountIsMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let accountID = UUID()
        let counterpartAccount = try Account.make(type: .savings)
        await accounts.save(counterpartAccount)
        let transaction = try Transaction.make(accountID: accountID, amount: 10)
        await transactions.save(transaction)

        await #expect(throws: AccountError.notFound) {
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: accountID,
                counterpartAccountID: counterpartAccount.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -10
            )
        }
        #expect(await transactions.all().count == 1)
    }

    @Test func failsWhenTransferAccountIsMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id, amount: 10)
        await transactions.save(transaction)

        await #expect(throws: AccountError.notFound) {
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                counterpartAccountID: UUID(),
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -10
            )
        }
        #expect(await transactions.all().count == 1)
    }

    @Test func failsWhenAccountIsClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        let counterpartAccount = try Account.make(type: .savings)
        await accounts.save(account)
        await accounts.save(counterpartAccount)
        let transaction = try Transaction.make(accountID: account.id, amount: 10)
        await transactions.save(transaction)

        await #expect(throws: AccountError.closed) {
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                counterpartAccountID: counterpartAccount.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -10
            )
        }
        #expect(await transactions.find(id: transaction.id)?.type == .standard)
        #expect(await transactions.all().count == 1)
    }

    @Test func failsWhenTransferAccountIsClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        let counterpartAccount = try Account.make(type: .savings, isClosed: true)
        await accounts.save(account)
        await accounts.save(counterpartAccount)
        let transaction = try Transaction.make(accountID: account.id, amount: 10)
        await transactions.save(transaction)

        await #expect(throws: AccountError.closed) {
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                counterpartAccountID: counterpartAccount.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -10
            )
        }
        #expect(await transactions.find(id: transaction.id)?.type == .standard)
        #expect(await transactions.all().count == 1)
    }
}
