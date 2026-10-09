import Foundation
import Testing
@testable import Haystack

struct ReduceSplitTests {
    @Test func reducesSplitWhenEveryPartIsRemoved() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try await ReduceSplit(unitOfWork: unitOfWork).execute(
            id: total.id,
            accountID: account.id,
            date: date,
            amount: 40,
            notes: "Adjusted",
            parts: []
        )
        let stored = try #require(await transactions.query(id: total.id))

        #expect(stored.type == .standard)
        #expect(stored.accountID == account.id)
        #expect(stored.amount == 40)
        #expect(stored.notes == "Adjusted")
        #expect(stored.date == date.asYearMonthDay())
        #expect(await transactions.query(id: grocery.id) == nil)
        #expect(await transactions.query(id: tax.id) == nil)
        #expect(await transactions.deleted(id: grocery.id) != nil)
        #expect(await transactions.deleted(id: tax.id) != nil)
        #expect(try await accounts.query(id: account.id)?.balance == 40)
    }

    @Test func reducesSplitWhenOnePartMatchesTotal() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: account.id, amount: 25)

        try await ReduceSplit(unitOfWork: unitOfWork).execute(
            id: total.id,
            accountID: account.id,
            date: .now,
            amount: 25,
            parts: [draftedGrocery]
        )
        let stored = try #require(await transactions.query(id: total.id))

        #expect(stored.type == .standard)
        #expect(stored.amount == 25)
        #expect(await transactions.query(id: grocery.id) == nil)
        #expect(await transactions.query(id: tax.id) == nil)
        #expect(await transactions.deleted(id: grocery.id) != nil)
        #expect(await transactions.deleted(id: tax.id) != nil)
        #expect(try await accounts.query(id: account.id)?.balance == 25)
    }

    @Test func movesReducedSplitOntoAnotherAccount() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let destination = try Account.make(name: "Savings", type: .savings)
        await accounts.save(destination)
        let amount: Decimal = 40

        try await ReduceSplit(unitOfWork: unitOfWork).execute(
            id: total.id,
            accountID: destination.id,
            date: .now,
            amount: amount,
            parts: []
        )
        let stored = try #require(await transactions.query(id: total.id))

        #expect(stored.type == .standard)
        #expect(stored.accountID == destination.id)
        #expect(stored.amount == amount)
        #expect(await transactions.query(id: grocery.id) == nil)
        #expect(await transactions.query(id: tax.id) == nil)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
        #expect(try await accounts.query(id: destination.id)?.balance == amount)
    }

    // MARK: Can execute

    @Test func failsWhenAmountIsZero() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()

        await #expect(throws: ApplicationError.cannotExecute) {
            try await ReduceSplit(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: account.id,
                date: .now,
                amount: 0,
                parts: []
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            total: total,
            grocery: grocery,
            tax: tax
        )
    }

    @Test func failsWhenOnePartAmountDiffers() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: account.id, amount: 20)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await ReduceSplit(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: account.id,
                date: .now,
                amount: 30,
                parts: [draftedGrocery]
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            total: total,
            grocery: grocery,
            tax: tax
        )
    }

    @Test func failsWhenMoreThanOnePart() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: account.id, amount: 20)
        let draftedTax = try Transaction.make(id: tax.id, accountID: account.id, amount: 10)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await ReduceSplit(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: account.id,
                date: .now,
                amount: 30,
                parts: [draftedGrocery, draftedTax]
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            total: total,
            grocery: grocery,
            tax: tax
        )
    }

    // MARK: Errors

    @Test func failsWhenMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)

        await #expect(throws: TransactionError.notFound) {
            try await ReduceSplit(unitOfWork: unitOfWork).execute(
                id: UUID(),
                accountID: account.id,
                date: .now,
                amount: 30,
                parts: []
            )
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenStoredPartIsTransfer() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let transferID = UUID()
        let parent = try Account.make(balance: -30)
        let other = try Account.make(name: "Bank", balance: 20)
        await accounts.save(parent)
        await accounts.save(other)
        let total = try Transaction.make(
            id: splitID,
            accountID: parent.id,
            amount: -30,
            type: .split(splitID)
        )
        let cash = try Transaction.make(
            accountID: parent.id,
            amount: -10,
            type: .splitPart(splitID, .standard)
        )
        let card = try Transaction.make(
            accountID: parent.id,
            amount: -20,
            notes: "Card",
            type: .splitPart(splitID, .transfer(transferID))
        )
        let incoming = try Transaction.make(
            accountID: other.id,
            amount: 20,
            notes: "Card",
            type: .transfer(transferID)
        )
        await transactions.save(total)
        await transactions.save(cash)
        await transactions.save(card)
        await transactions.save(incoming)

        await #expect(throws: SplitError.malformed) {
            try await ReduceSplit(unitOfWork: unitOfWork).execute(
                id: splitID,
                accountID: parent.id,
                date: .now,
                amount: -30,
                parts: []
            )
        }
        let storedTotal = try #require(await transactions.query(id: splitID))
        let storedCard = try #require(await transactions.query(id: card.id))
        let storedIncoming = try #require(await transactions.query(id: incoming.id))
        #expect(storedTotal.type == .split(splitID))
        #expect(storedCard.amount == -20)
        #expect(storedCard.type == .splitPart(splitID, .transfer(transferID)))
        #expect(storedIncoming.amount == 20)
        #expect(storedIncoming.type == .transfer(transferID))
        #expect(try await accounts.query(id: parent.id)?.balance == -30)
        #expect(try await accounts.query(id: other.id)?.balance == 20)
    }

    @Test func failsWhenAccountIsMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let accountID = UUID()
        let total = try Transaction.make(
            id: splitID,
            accountID: accountID,
            amount: 30,
            type: .split(splitID)
        )
        let grocery = try Transaction.make(
            accountID: accountID,
            amount: 20,
            type: .splitPart(splitID, .standard)
        )
        let tax = try Transaction.make(
            accountID: accountID,
            amount: 10,
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(total)
        await transactions.save(grocery)
        await transactions.save(tax)

        await #expect(throws: AccountError.notFound) {
            try await ReduceSplit(unitOfWork: unitOfWork).execute(
                id: splitID,
                accountID: accountID,
                date: .now,
                amount: 30,
                parts: []
            )
        }
        #expect(await transactions.query(id: total.id)?.type == .split(splitID))
        #expect(await transactions.query(id: grocery.id)?.amount == 20)
        #expect(await transactions.query(id: tax.id)?.amount == 10)
        #expect(await accounts.all().isEmpty)
    }

    @Test func failsWhenClosed() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit(
            isClosed: true
        )

        await #expect(throws: AccountError.closed) {
            try await ReduceSplit(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: account.id,
                date: .now,
                amount: 30,
                parts: []
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            total: total,
            grocery: grocery,
            tax: tax
        )
    }

    @Test func failsWhenDestinationIsMissing() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let destinationID = UUID()

        await #expect(throws: AccountError.notFound) {
            try await ReduceSplit(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: destinationID,
                date: .now,
                amount: 30,
                parts: []
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            total: total,
            grocery: grocery,
            tax: tax
        )
    }

    @Test func failsWhenDestinationIsClosed() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let destination = try Account.make(name: "Savings", type: .savings, isClosed: true)
        await accounts.save(destination)

        await #expect(throws: AccountError.closed) {
            try await ReduceSplit(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: destination.id,
                date: .now,
                amount: 30,
                parts: []
            )
        }
        try await expectUnchanged(
            accounts: accounts,
            transactions: transactions,
            account: account,
            total: total,
            grocery: grocery,
            tax: tax
        )
        #expect(try await accounts.query(id: destination.id)?.balance == 0)
    }

    private func makeSplit(isClosed: Bool = false) async throws -> (
        InMemoryAccountRepository,
        InMemoryTransactionRepository,
        InMemoryUnitOfWork,
        Account,
        Transaction,
        Transaction,
        Transaction
    ) {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let account = try Account.make(balance: 30, isClosed: isClosed)
        await accounts.save(account)
        let total = try Transaction.make(
            id: splitID,
            accountID: account.id,
            amount: 30,
            type: .split(splitID)
        )
        let grocery = try Transaction.make(
            accountID: account.id,
            amount: 20,
            notes: "Groceries",
            type: .splitPart(splitID, .standard)
        )
        let tax = try Transaction.make(
            accountID: account.id,
            amount: 10,
            notes: "Tax",
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(total)
        await transactions.save(grocery)
        await transactions.save(tax)
        return (accounts, transactions, unitOfWork, account, total, grocery, tax)
    }

    private func expectUnchanged(
        accounts: InMemoryAccountRepository,
        transactions: InMemoryTransactionRepository,
        account: Account,
        total: Transaction,
        grocery: Transaction,
        tax: Transaction
    ) async throws {
        #expect(await transactions.query(id: total.id)?.type == .split(total.id))
        #expect(await transactions.query(id: grocery.id)?.amount == grocery.amount)
        #expect(await transactions.query(id: tax.id)?.amount == tax.amount)
        #expect(try await accounts.query(id: account.id)?.balance == account.balance)
    }
}
