import Foundation
import Testing
@testable import Haystack

struct ConvertTransactionToSplitTests {
    @Test func convertsStandardTransactionIntoSplit() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(balance: 10)
        await accounts.save(account)
        let transaction = try Transaction.make(
            accountID: account.id,
            date: (year: 2026, month: 8, day: 31),
            amount: 10,
            notes: "Lunch"
        )
        await transactions.save(transaction)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let grocery = try Transaction.make(amount: 20, notes: "Groceries")
        let tax = try Transaction.make(amount: 10, notes: "Tax")

        try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
            id: transaction.id,
            accountID: account.id,
            date: date,
            amount: 30,
            notes: "Market",
            parts: [grocery, tax]
        )
        let stored = try #require(await transactions.query(id: transaction.id))
        let created = await transactions.all().filter { $0.id != transaction.id }
        let storedGrocery = try #require(created.first { $0.notes == "Groceries" })
        let storedTax = try #require(created.first { $0.notes == "Tax" })
        let (total, parts) = try #require(await transactions.querySplit(id: transaction.id))

        #expect(stored.id == transaction.id)
        #expect(stored.type == .split(transaction.id))
        #expect(stored.accountID == account.id)
        #expect(stored.amount == 30)
        #expect(stored.notes == "Market")
        #expect(stored.date == date.asYearMonthDay())
        #expect(storedGrocery.id != grocery.id)
        #expect(storedGrocery.type == .splitPart(transaction.id, .standard))
        #expect(storedGrocery.accountID == account.id)
        #expect(storedGrocery.amount == 20)
        #expect(storedGrocery.notes == "Groceries")
        #expect(storedGrocery.date == date.asYearMonthDay())
        #expect(storedTax.id != tax.id)
        #expect(storedTax.type == .splitPart(transaction.id, .standard))
        #expect(storedTax.accountID == account.id)
        #expect(storedTax.amount == 10)
        #expect(storedTax.notes == "Tax")
        #expect(storedTax.date == date.asYearMonthDay())
        #expect(total.id == stored.id)
        #expect(Set(parts.map(\.id)) == Set(created.map(\.id)))
        #expect(try await accounts.query(id: account.id)?.balance == 30)
        #expect(await transactions.all().count == 3)
    }

    @Test func movesConvertedSplitOntoAnotherAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let source = try Account.make(name: "Wallet", balance: 10)
        let destination = try Account.make(name: "Savings", type: .savings)
        await accounts.save(source)
        await accounts.save(destination)
        let transaction = try Transaction.make(accountID: source.id, amount: 10)
        await transactions.save(transaction)
        let parts = try [
            Transaction.make(amount: 20),
            Transaction.make(amount: 10),
        ]

        try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
            id: transaction.id,
            accountID: destination.id,
            date: .now,
            amount: 30,
            parts: parts
        )
        let (total, splitParts) = try #require(await transactions.querySplit(id: transaction.id))

        #expect(total.accountID == destination.id)
        #expect(splitParts.count == 2)
        #expect(splitParts.allSatisfy { $0.accountID == destination.id })
        #expect(try await accounts.query(id: source.id)?.balance == 0)
        #expect(try await accounts.query(id: destination.id)?.balance == 30)
    }

    // MARK: Can execute

    @Test func failsWhenAmountIsZero() async throws {
        let (accounts, transactions, unitOfWork, account, transaction) = try await makeTransaction()
        let parts = try [
            Transaction.make(amount: 5),
            Transaction.make(amount: -5),
        ]

        await #expect(throws: ApplicationError.cannotExecute) {
            try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 0,
                parts: parts
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            transaction: transaction
        )
    }

    @Test func failsWhenFewerThanTwoParts() async throws {
        let (accounts, transactions, unitOfWork, account, transaction) = try await makeTransaction()
        let part = try Transaction.make(amount: 30)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 30,
                parts: [part]
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            transaction: transaction
        )
    }

    @Test func failsWhenPartsDoNotSumToAmount() async throws {
        let (accounts, transactions, unitOfWork, account, transaction) = try await makeTransaction()
        let parts = try [
            Transaction.make(amount: 20),
            Transaction.make(amount: 5),
        ]

        await #expect(throws: ApplicationError.cannotExecute) {
            try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 30,
                parts: parts
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            transaction: transaction
        )
    }

    // MARK: Errors

    @Test func failsWhenMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        let parts = try [
            Transaction.make(amount: 20),
            Transaction.make(amount: 10),
        ]

        await #expect(throws: TransactionError.notFound) {
            try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
                id: UUID(),
                accountID: account.id,
                date: .now,
                amount: 30,
                parts: parts
            )
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenTransactionIsTransfer() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(balance: 10)
        await accounts.save(account)
        let transferID = UUID()
        let transaction = try Transaction.make(
            accountID: account.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(transaction)
        let parts = try [
            Transaction.make(amount: 20),
            Transaction.make(amount: 10),
        ]

        await #expect(throws: TransactionError.notFound) {
            try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 30,
                parts: parts
            )
        }
        #expect(await transactions.query(id: transaction.id)?.type == .transfer(transferID))
        #expect(await transactions.query(id: transaction.id)?.amount == 10)
        #expect(await transactions.all().count == 1)
        #expect(try await accounts.query(id: account.id)?.balance == 10)
    }

    @Test func failsWhenAccountIsMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let accountID = UUID()
        let transaction = try Transaction.make(accountID: accountID, amount: 10)
        await transactions.save(transaction)
        let parts = try [
            Transaction.make(amount: 20),
            Transaction.make(amount: 10),
        ]

        await #expect(throws: AccountError.notFound) {
            try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: accountID,
                date: .now,
                amount: 30,
                parts: parts
            )
        }
        #expect(await transactions.query(id: transaction.id)?.type == .standard)
        #expect(await transactions.query(id: transaction.id)?.amount == 10)
        #expect(await transactions.all().count == 1)
        #expect(await accounts.all().isEmpty)
    }

    @Test func failsWhenAccountIsClosed() async throws {
        let (accounts, transactions, unitOfWork, account, transaction) = try await makeTransaction(isClosed: true)
        let parts = try [
            Transaction.make(amount: 20),
            Transaction.make(amount: 10),
        ]

        await #expect(throws: AccountError.closed) {
            try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 30,
                parts: parts
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            transaction: transaction
        )
    }

    @Test func failsWhenDestinationAccountIsMissing() async throws {
        let (accounts, transactions, unitOfWork, account, transaction) = try await makeTransaction()
        let destinationID = UUID()
        let parts = try [
            Transaction.make(amount: 20),
            Transaction.make(amount: 10),
        ]

        await #expect(throws: AccountError.notFound) {
            try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: destinationID,
                date: .now,
                amount: 30,
                parts: parts
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            transaction: transaction
        )
    }

    @Test func failsWhenDestinationAccountIsClosed() async throws {
        let (accounts, transactions, unitOfWork, account, transaction) = try await makeTransaction()
        let destination = try Account.make(name: "Savings", type: .savings, isClosed: true)
        await accounts.save(destination)
        let parts = try [
            Transaction.make(amount: 20),
            Transaction.make(amount: 10),
        ]

        await #expect(throws: AccountError.closed) {
            try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: destination.id,
                date: .now,
                amount: 30,
                parts: parts
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            transaction: transaction
        )
        #expect(try await accounts.query(id: destination.id)?.balance == 0)
    }

    @Test func failsWhenPartIsTransfer() async throws {
        let (accounts, transactions, unitOfWork, account, transaction) = try await makeTransaction()
        let parts = try [
            Transaction.make(amount: 20),
            Transaction.make(amount: 10, type: .transfer(UUID())),
        ]

        await #expect(throws: SplitError.malformed) {
            try await ConvertTransactionToSplit(unitOfWork: unitOfWork).execute(
                id: transaction.id,
                accountID: account.id,
                date: .now,
                amount: 30,
                parts: parts
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            transaction: transaction
        )
    }

    private func makeTransaction(isClosed: Bool = false) async throws -> (
        InMemoryAccountRepository,
        InMemoryTransactionRepository,
        InMemoryUnitOfWork,
        Account,
        Transaction
    ) {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(balance: 10, isClosed: isClosed)
        await accounts.save(account)
        let transaction = try Transaction.make(accountID: account.id, amount: 10, notes: "Lunch")
        await transactions.save(transaction)
        return (accounts, transactions, unitOfWork, account, transaction)
    }

    private func expectUnchanged(
        accounts: InMemoryAccountRepository,
        transactions: InMemoryTransactionRepository,
        account: Account,
        transaction: Transaction
    ) async throws {
        let stored = try #require(await transactions.query(id: transaction.id))
        #expect(stored.type == .standard)
        #expect(stored.amount == transaction.amount)
        #expect(await transactions.all().count == 1)
        #expect(try await accounts.query(id: account.id)?.balance == account.balance)
    }
}
