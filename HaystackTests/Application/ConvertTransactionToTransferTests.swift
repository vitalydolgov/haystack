import Foundation
import Testing
@testable import Haystack

struct ConvertTransactionToTransferTests {
    @Test func convertsTransactionAndCreatesCounterpart() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(name: "Wallet", balance: 10)
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

        let stored = try #require(await transactions.query(id: transaction.id))
        #expect(stored.accountID == account.id)
        #expect(stored.type.transferID != nil)
        #expect(stored.amount == -12.5)
        #expect(stored.notes == "Coffee")
        #expect(stored.date == date.asYearMonthDay())

        let transferID = try #require(stored.type.transferID)
        let counterpart = try #require(await transactions.all().first { $0.id != stored.id })
        #expect(counterpart.accountID == counterpartAccount.id)
        #expect(counterpart.type.transferID != nil)
        #expect(counterpart.type.transferID == transferID)
        #expect(counterpart.amount == 12.5)
        #expect(counterpart.notes == "Coffee")
        #expect(counterpart.date == date.asYearMonthDay())
        #expect(await transactions.all().count == 2)
        #expect(try await accounts.query(id: account.id)?.balance == -12.5)
        #expect(try await accounts.query(id: counterpartAccount.id)?.balance == 12.5)
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

        let stored = try #require(await transactions.query(id: transaction.id))
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

        let stored = try #require(await transactions.query(id: transaction.id))
        #expect(stored.accountID == targetAccount.id)
        #expect(stored.type.transferID != nil)
        let counterpart = try #require(await transactions.all().first { $0.id != stored.id })
        #expect(counterpart.accountID == counterpartAccount.id)
        #expect(counterpart.type.transferID == stored.type.transferID)
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
        #expect(await transactions.query(id: transaction.id)?.type == .standard)
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
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(amount: 10, type: .transfer(transferID))
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
        #expect(await transactions.query(id: fromLeg.id)?.type.transferID == transferID)
        #expect(await transactions.query(id: toLeg.id)?.type.transferID == transferID)
        #expect(await transactions.all().count == 2)
    }

    @Test func failsWhenSplit() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(balance: 0)
        let counterpartAccount = try Account.make(type: .savings)
        await accounts.save(account)
        await accounts.save(counterpartAccount)
        let splitID = UUID()
        let total = try Transaction.make(
            id: splitID,
            accountID: account.id,
            amount: -30,
            type: .split(splitID)
        )
        await transactions.save(total)

        await #expect(throws: TransactionError.notFound) {
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: account.id,
                counterpartAccountID: counterpartAccount.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -30
            )
        }
        #expect(await transactions.query(id: total.id)?.type == .split(splitID))
        #expect(await transactions.all().count == 1)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
        #expect(try await accounts.query(id: counterpartAccount.id)?.balance == 0)
    }

    @Test func failsWhenSplitPart() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(balance: -10)
        let counterpartAccount = try Account.make(type: .savings)
        await accounts.save(account)
        await accounts.save(counterpartAccount)
        let splitID = UUID()
        let part = try Transaction.make(
            accountID: account.id,
            amount: -10,
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(part)

        await #expect(throws: TransactionError.notFound) {
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: part.id,
                accountID: account.id,
                counterpartAccountID: counterpartAccount.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -10
            )
        }
        #expect(await transactions.query(id: part.id)?.type == .splitPart(splitID, .standard))
        #expect(await transactions.all().count == 1)
        #expect(try await accounts.query(id: account.id)?.balance == -10)
        #expect(try await accounts.query(id: counterpartAccount.id)?.balance == 0)
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
        #expect(await transactions.query(id: transaction.id)?.type == .standard)
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
        #expect(await transactions.query(id: transaction.id)?.type == .standard)
        #expect(await transactions.all().count == 1)
    }

    @Test func failsWhenAmountIsZero() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        let counterpartAccount = try Account.make(type: .savings)
        await accounts.save(account)
        await accounts.save(counterpartAccount)
        let transaction = try Transaction.make(accountID: account.id, amount: 10)
        await transactions.save(transaction)

        await #expect(throws: TransactionError.invalidAmount) {
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                counterpartAccountID: counterpartAccount.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: 0
            )
        }
        #expect(await transactions.query(id: transaction.id)?.type == .standard)
        #expect(await transactions.all().count == 1)
    }
}
