import Foundation
import Testing
@testable import Haystack

struct EditSplitTests {
    @Test func updatesTotalAndPartsInPlace() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let account = try Account.make(balance: 30)
        await accounts.save(account)
        let total = try Transaction.make(
            id: splitID,
            accountID: account.id,
            date: (year: 2026, month: 8, day: 31),
            amount: 30,
            notes: "Market",
            type: .split(splitID)
        )
        let grocery = try Transaction.make(
            accountID: account.id,
            date: (year: 2026, month: 8, day: 31),
            amount: 20,
            notes: "Groceries",
            type: .splitPart(splitID, .standard)
        )
        let tax = try Transaction.make(
            accountID: account.id,
            date: (year: 2026, month: 8, day: 31),
            amount: 10,
            notes: "Tax",
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(total)
        await transactions.save(grocery)
        await transactions.save(tax)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let draftedGrocery = try Transaction.make(
            id: grocery.id,
            accountID: account.id,
            amount: -15,
            notes: "Ignored groceries"
        )
        let draftedTax = try Transaction.make(
            id: tax.id,
            accountID: account.id,
            amount: 5,
            notes: "Ignored tax"
        )

        try await EditSplit(unitOfWork: unitOfWork).execute(
            id: splitID,
            accountID: account.id,
            date: date,
            amount: -10,
            notes: "Adjusted",
            parts: [draftedGrocery, draftedTax]
        )
        let storedTotal = try #require(await transactions.query(id: splitID))
        let storedGrocery = try #require(await transactions.query(id: grocery.id))
        let storedTax = try #require(await transactions.query(id: tax.id))
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let year = try #require(components.year)
        let month = try #require(components.month)
        let day = try #require(components.day)

        #expect(storedTotal.date == (year: year, month: month, day: day))
        #expect(storedTotal.amount == -10)
        #expect(storedTotal.notes == "Adjusted")
        #expect(storedGrocery.amount == -15)
        #expect(storedTax.amount == 5)
        #expect(storedGrocery.date == storedTotal.date)
        #expect(storedTax.date == storedTotal.date)
        #expect(storedGrocery.notes == "Groceries")
        #expect(storedTax.notes == "Tax")
        #expect(try await accounts.query(id: account.id)?.balance == -10)
    }

    @Test func addsPartAndDeletesRemovedPart() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let account = try Account.make(balance: 30)
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
            type: .splitPart(splitID, .standard)
        )
        let tax = try Transaction.make(
            accountID: account.id,
            amount: 10,
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(total)
        await transactions.save(grocery)
        await transactions.save(tax)
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: account.id, amount: 20)
        let fee = try Transaction.make(
            accountID: account.id,
            amount: 15,
            notes: "Fee"
        )

        try await EditSplit(unitOfWork: unitOfWork).execute(
            id: splitID,
            accountID: account.id,
            date: .now,
            amount: 35,
            parts: [draftedGrocery, fee]
        )

        #expect(await transactions.query(id: grocery.id) != nil)
        #expect(await transactions.query(id: tax.id) == nil)
        #expect(await transactions.deleted(id: tax.id) != nil)
        let added = await transactions.all().filter { $0.id != total.id && $0.id != grocery.id }
        #expect(added.count == 1)
        let storedFee = try #require(added.first)
        #expect(storedFee.amount == 15)
        #expect(storedFee.notes == "Fee")
        #expect(storedFee.type == .splitPart(splitID, .standard))
        #expect(try await accounts.query(id: account.id)?.balance == 35)
    }

    @Test func movesSplitOntoAnotherAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let source = try Account.make(name: "Wallet", balance: 30)
        let destination = try Account.make(name: "Savings", type: .savings)
        await accounts.save(source)
        await accounts.save(destination)
        let total = try Transaction.make(
            id: splitID,
            accountID: source.id,
            amount: 30,
            type: .split(splitID)
        )
        let grocery = try Transaction.make(
            accountID: source.id,
            amount: 20,
            type: .splitPart(splitID, .standard)
        )
        let tax = try Transaction.make(
            accountID: source.id,
            amount: 10,
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(total)
        await transactions.save(grocery)
        await transactions.save(tax)
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: destination.id, amount: 12)
        let draftedTax = try Transaction.make(id: tax.id, accountID: destination.id, amount: 8)

        try await EditSplit(unitOfWork: unitOfWork).execute(
            id: splitID,
            accountID: destination.id,
            date: .now,
            amount: 20,
            parts: [draftedGrocery, draftedTax]
        )
        let storedTotal = try #require(await transactions.query(id: splitID))
        let storedGrocery = try #require(await transactions.query(id: grocery.id))
        let storedTax = try #require(await transactions.query(id: tax.id))

        #expect(storedTotal.accountID == destination.id)
        #expect(storedGrocery.accountID == destination.id)
        #expect(storedTax.accountID == destination.id)
        #expect(try await accounts.query(id: source.id)?.balance == 0)
        #expect(try await accounts.query(id: destination.id)?.balance == 20)
    }

    @Test func convertsSplitToStandardTransactionWhenEveryPartIsRemoved() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try await EditSplit(unitOfWork: unitOfWork).execute(
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

    @Test func convertsSplitToStandardTransactionWhenOnePartRemains() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: account.id, amount: 5)

        try await EditSplit(unitOfWork: unitOfWork).execute(
            id: total.id,
            accountID: account.id,
            date: .now,
            amount: 25,
            parts: [draftedGrocery]
        )
        let stored = try #require(await transactions.query(id: total.id))
        let splitParts = await transactions.all().filter { transaction in
            if case .splitPart = transaction.type { true } else { false }
        }

        #expect(stored.type == .standard)
        #expect(stored.amount == 25)
        #expect(await transactions.query(id: grocery.id) == nil)
        #expect(await transactions.query(id: tax.id) == nil)
        #expect(await transactions.deleted(id: grocery.id) != nil)
        #expect(await transactions.deleted(id: tax.id) != nil)
        #expect(splitParts.isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 25)
    }

    @Test func movesConvertedSplitOntoAnotherAccount() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let destination = try Account.make(name: "Savings", type: .savings)
        await accounts.save(destination)
        let amount: Decimal = 40

        try await EditSplit(unitOfWork: unitOfWork).execute(
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
        #expect(await transactions.deleted(id: grocery.id) != nil)
        #expect(await transactions.deleted(id: tax.id) != nil)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
        #expect(try await accounts.query(id: destination.id)?.balance == amount)
    }

    // MARK: Can execute

    @Test func failsWhenAmountIsZero() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: account.id, amount: 20)
        let draftedTax = try Transaction.make(id: tax.id, accountID: account.id, amount: 10)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await EditSplit(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: account.id,
                date: .now,
                amount: 0,
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

    @Test func failsWhenAmountsDiffer() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: account.id, amount: 20)
        let draftedTax = try Transaction.make(id: tax.id, accountID: account.id, amount: 10)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await EditSplit(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: account.id,
                date: .now,
                amount: 40,
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
        let parts = try [
            Transaction.make(accountID: account.id, amount: 20),
            Transaction.make(accountID: account.id, amount: 10),
        ]

        await #expect(throws: TransactionError.notFound) {
            try await EditSplit(unitOfWork: unitOfWork).execute(
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
        let draftedCash = try Transaction.make(id: cash.id, accountID: parent.id, amount: -5)
        let draftedCard = try Transaction.make(id: card.id, accountID: parent.id, amount: -25)

        await #expect(throws: SplitError.malformed) {
            try await EditSplit(unitOfWork: unitOfWork).execute(
                id: splitID,
                accountID: parent.id,
                date: .now,
                amount: -30,
                parts: [draftedCash, draftedCard]
            )
        }
        let storedCard = try #require(await transactions.query(id: card.id))
        let storedIncoming = try #require(await transactions.query(id: incoming.id))
        #expect(storedCard.amount == -20)
        #expect(storedCard.accountID == parent.id)
        #expect(storedCard.type == .splitPart(splitID, .transfer(transferID)))
        #expect(storedIncoming.amount == 20)
        #expect(storedIncoming.accountID == other.id)
        #expect(storedIncoming.type == .transfer(transferID))
        #expect(try await accounts.query(id: parent.id)?.balance == -30)
        #expect(try await accounts.query(id: other.id)?.balance == 20)
    }

    @Test func failsWhenConvertedSplitContainsTransfer() async throws {
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
            try await EditSplit(unitOfWork: unitOfWork).execute(
                id: splitID,
                accountID: parent.id,
                date: .now,
                amount: -30,
                parts: []
            )
        }
        let storedTotal = try #require(await transactions.query(id: splitID))
        let storedCash = try #require(await transactions.query(id: cash.id))
        let storedCard = try #require(await transactions.query(id: card.id))
        let storedIncoming = try #require(await transactions.query(id: incoming.id))
        #expect(storedTotal.type == .split(splitID))
        #expect(storedCash.amount == -10)
        #expect(storedCash.type == .splitPart(splitID, .standard))
        #expect(storedCard.amount == -20)
        #expect(storedCard.accountID == parent.id)
        #expect(storedCard.type == .splitPart(splitID, .transfer(transferID)))
        #expect(storedIncoming.amount == 20)
        #expect(storedIncoming.accountID == other.id)
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
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: accountID, amount: 20)
        let draftedTax = try Transaction.make(id: tax.id, accountID: accountID, amount: 10)

        await #expect(throws: AccountError.notFound) {
            try await EditSplit(unitOfWork: unitOfWork).execute(
                id: splitID,
                accountID: accountID,
                date: .now,
                amount: 30,
                parts: [draftedGrocery, draftedTax]
            )
        }
        #expect(await transactions.query(id: total.id)?.amount == 30)
        #expect(await transactions.query(id: grocery.id)?.amount == 20)
        #expect(await transactions.query(id: tax.id)?.amount == 10)
        #expect(await accounts.all().isEmpty)
    }

    @Test func failsWhenClosed() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit(
            isClosed: true
        )
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: account.id, amount: 15)
        let draftedTax = try Transaction.make(id: tax.id, accountID: account.id, amount: 15)

        await #expect(throws: AccountError.closed) {
            try await EditSplit(unitOfWork: unitOfWork).execute(
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

    @Test func failsWhenDestinationIsMissing() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let destinationID = UUID()
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: destinationID, amount: 20)
        let draftedTax = try Transaction.make(id: tax.id, accountID: destinationID, amount: 10)

        await #expect(throws: AccountError.notFound) {
            try await EditSplit(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: destinationID,
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

    @Test func failsWhenDestinationIsClosed() async throws {
        let (accounts, transactions, unitOfWork, account, total, grocery, tax) = try await makeSplit()
        let destination = try Account.make(name: "Savings", type: .savings, isClosed: true)
        await accounts.save(destination)
        let draftedGrocery = try Transaction.make(id: grocery.id, accountID: destination.id, amount: 12)
        let draftedTax = try Transaction.make(id: tax.id, accountID: destination.id, amount: 8)

        await #expect(throws: AccountError.closed) {
            try await EditSplit(unitOfWork: unitOfWork).execute(
                id: total.id,
                accountID: destination.id,
                date: .now,
                amount: 20,
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
        #expect(await transactions.query(id: total.id)?.amount == total.amount)
        #expect(await transactions.query(id: grocery.id)?.amount == grocery.amount)
        #expect(await transactions.query(id: tax.id)?.amount == tax.amount)
        #expect(await transactions.query(id: total.id)?.accountID == total.accountID)
        #expect(await transactions.query(id: grocery.id)?.accountID == grocery.accountID)
        #expect(await transactions.query(id: tax.id)?.accountID == tax.accountID)
        #expect(try await accounts.query(id: account.id)?.balance == account.balance)
    }
}
