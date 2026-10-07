import Foundation
import Testing
@testable import Haystack

struct AddSplitTests {
    @Test func createsSplitFromStandardParts() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        let suppliedTotalID = UUID()
        let suppliedGroceryID = UUID()
        let suppliedTaxID = UUID()
        let total = try Transaction.make(
            id: suppliedTotalID,
            accountID: account.id,
            date: (year: 2026, month: 3, day: 2),
            amount: 30,
            notes: "Market"
        )
        let grocery = try Transaction.make(
            id: suppliedGroceryID,
            accountID: account.id,
            date: (year: 2026, month: 3, day: 2),
            amount: 20,
            notes: "Groceries"
        )
        let tax = try Transaction.make(
            id: suppliedTaxID,
            accountID: account.id,
            date: (year: 2026, month: 3, day: 3),
            amount: 10,
            notes: "Tax"
        )

        let (split, parts) = try await AddSplit(unitOfWork: unitOfWork).execute(
            total,
            parts: [grocery, tax]
        )

        #expect(split.id != suppliedTotalID)
        #expect(split.accountID == account.id)
        #expect(split.date == (year: 2026, month: 3, day: 2))
        #expect(split.amount == 30)
        #expect(split.notes == "Market")
        #expect(split.type == .split(split.id))
        #expect(parts.count == 2)
        #expect(parts[0].id != suppliedGroceryID)
        #expect(parts[0].accountID == account.id)
        #expect(parts[0].date == (year: 2026, month: 3, day: 2))
        #expect(parts[0].amount == 20)
        #expect(parts[0].notes == "Groceries")
        #expect(parts[0].type == .splitPart(split.id, .standard))
        #expect(parts[1].id != suppliedTaxID)
        #expect(parts[1].accountID == account.id)
        #expect(parts[1].date == (year: 2026, month: 3, day: 3))
        #expect(parts[1].amount == 10)
        #expect(parts[1].notes == "Tax")
        #expect(parts[1].type == .splitPart(split.id, .standard))

        let storedSplit = try #require(await transactions.query(id: split.id))
        #expect(storedSplit.type == .split(split.id))
        #expect(storedSplit.amount == 30)
        #expect(storedSplit.notes == "Market")
        let storedGrocery = try #require(await transactions.query(id: parts[0].id))
        #expect(storedGrocery.amount == 20)
        #expect(storedGrocery.notes == "Groceries")
        #expect(storedGrocery.type == .splitPart(split.id, .standard))
        let storedTax = try #require(await transactions.query(id: parts[1].id))
        #expect(storedTax.amount == 10)
        #expect(storedTax.notes == "Tax")
        #expect(storedTax.type == .splitPart(split.id, .standard))
        #expect(await transactions.query(.account(account.id)).count == 3)
        #expect(try await accounts.query(id: account.id)?.balance == 30)
    }

    @Test func createsSplitWithOutgoingTransfer() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let parent = try Account.make()
        let other = try Account.make(name: "Bank")
        await accounts.save(parent)
        await accounts.save(other)
        let suppliedTransferID = UUID()
        let total = try Transaction.make(
            accountID: parent.id,
            date: (year: 2026, month: 3, day: 2),
            amount: -30,
            notes: "Market"
        )
        let cash = try Transaction.make(
            accountID: parent.id,
            date: (year: 2026, month: 3, day: 2),
            amount: -10,
            notes: "Cash"
        )
        let card = try Transaction.make(
            accountID: other.id,
            date: (year: 2026, month: 3, day: 4),
            amount: -20,
            notes: "Card",
            type: .transfer(suppliedTransferID)
        )

        let (split, parts) = try await AddSplit(unitOfWork: unitOfWork).execute(
            total,
            parts: [cash, card]
        )

        #expect(split.type == .split(split.id))
        #expect(split.amount == -30)
        #expect(parts.count == 2)
        #expect(parts[0].accountID == parent.id)
        #expect(parts[0].amount == -10)
        #expect(parts[0].notes == "Cash")
        #expect(parts[0].type == .splitPart(split.id, .standard))
        #expect(parts[1].accountID == parent.id)
        #expect(parts[1].amount == -20)
        #expect(parts[1].date == (year: 2026, month: 3, day: 4))
        #expect(parts[1].notes == "Card")
        let transferID = try #require(parts[1].type.transferID)
        #expect(transferID != suppliedTransferID)
        #expect(parts[1].type == .splitPart(split.id, .transfer(transferID)))

        let (outgoing, incoming) = try #require(
            try await transactions.queryTransfer(id: transferID, relativeTo: parent.id)
        )
        #expect(outgoing.id == parts[1].id)
        #expect(outgoing.accountID == parent.id)
        #expect(outgoing.amount == -20)
        #expect(outgoing.notes == "Card")
        #expect(incoming.accountID == other.id)
        #expect(incoming.amount == 20)
        #expect(incoming.notes == "Card")
        #expect(incoming.date == (year: 2026, month: 3, day: 4))
        #expect(await transactions.query(.account(parent.id)).count == 3)
        #expect(await transactions.query(.account(other.id)).count == 1)
        #expect(try await accounts.query(id: parent.id)?.balance == -30)
        #expect(try await accounts.query(id: other.id)?.balance == 20)
    }

    @Test func createsSplitWithIncomingTransfer() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let parent = try Account.make()
        let other = try Account.make(name: "Bank")
        await accounts.save(parent)
        await accounts.save(other)
        let total = try Transaction.make(accountID: parent.id, amount: 30, notes: "Refund")
        let cash = try Transaction.make(accountID: parent.id, amount: 10, notes: "Cash")
        let card = try Transaction.make(
            accountID: other.id,
            amount: 20,
            notes: "Card",
            type: .transfer(UUID())
        )

        let (split, parts) = try await AddSplit(unitOfWork: unitOfWork).execute(
            total,
            parts: [cash, card]
        )

        #expect(split.type == .split(split.id))
        #expect(parts[0].type == .splitPart(split.id, .standard))
        #expect(parts[0].amount == 10)
        #expect(parts[1].accountID == parent.id)
        #expect(parts[1].amount == 20)
        #expect(parts[1].notes == "Card")
        let transferID = try #require(parts[1].type.transferID)
        let (outgoing, incoming) = try #require(
            try await transactions.queryTransfer(id: transferID, relativeTo: other.id)
        )
        #expect(outgoing.accountID == other.id)
        #expect(outgoing.amount == -20)
        #expect(outgoing.notes == "Card")
        #expect(incoming.id == parts[1].id)
        #expect(incoming.accountID == parent.id)
        #expect(incoming.amount == 20)
        #expect(await transactions.query(.account(parent.id)).count == 3)
        #expect(await transactions.query(.account(other.id)).count == 1)
        #expect(try await accounts.query(id: parent.id)?.balance == 30)
        #expect(try await accounts.query(id: other.id)?.balance == -20)
    }

    // MARK: Can execute

    @Test func failsWhenTotalIsTransfer() async throws {
        let (accounts, transactions, unitOfWork, account) = try await openAccount()
        let total = try Transaction.make(accountID: account.id, amount: 30, type: .transfer(UUID()))
        let parts = try standardParts(accountID: account.id, amounts: [20, 10])

        await #expect(throws: ApplicationError.cannotExecute) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: parts)
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenTotalIsSplit() async throws {
        let (accounts, transactions, unitOfWork, account) = try await openAccount()
        let total = try Transaction.make(accountID: account.id, amount: 30, type: .split(UUID()))
        let parts = try standardParts(accountID: account.id, amounts: [20, 10])

        await #expect(throws: ApplicationError.cannotExecute) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: parts)
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenTotalIsSplitPart() async throws {
        let (accounts, transactions, unitOfWork, account) = try await openAccount()
        let total = try Transaction.make(
            accountID: account.id,
            amount: 30,
            type: .splitPart(UUID(), .standard)
        )
        let parts = try standardParts(accountID: account.id, amounts: [20, 10])

        await #expect(throws: ApplicationError.cannotExecute) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: parts)
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test(arguments: [0, 1])
    func failsWhenPartCountIsBelowTwo(count: Int) async throws {
        let (accounts, transactions, unitOfWork, account) = try await openAccount()
        let total = try Transaction.make(accountID: account.id, amount: 10)
        let parts = try (0..<count).map { _ in
            try Transaction.make(accountID: account.id, amount: 10)
        }

        await #expect(throws: ApplicationError.cannotExecute) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: parts)
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenPartIDsRepeat() async throws {
        let (accounts, transactions, unitOfWork, account) = try await openAccount()
        let sharedID = UUID()
        let total = try Transaction.make(accountID: account.id, amount: 10)
        let first = try Transaction.make(id: sharedID, accountID: account.id, amount: 6)
        let second = try Transaction.make(id: sharedID, accountID: account.id, amount: 4)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: [first, second])
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenStandardPartAccountDiffers() async throws {
        let (accounts, transactions, unitOfWork, account) = try await openAccount()
        let total = try Transaction.make(accountID: account.id, amount: 10)
        let elsewhere = try Transaction.make(accountID: UUID(), amount: 6)
        let local = try Transaction.make(accountID: account.id, amount: 4)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: [elsewhere, local])
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenTransferPartAccountMatches() async throws {
        let (accounts, transactions, unitOfWork, account) = try await openAccount()
        let total = try Transaction.make(accountID: account.id, amount: 10)
        let local = try Transaction.make(accountID: account.id, amount: 6)
        let transfer = try Transaction.make(accountID: account.id, amount: 4, type: .transfer(UUID()))

        await #expect(throws: ApplicationError.cannotExecute) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: [local, transfer])
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenPartIsSplit() async throws {
        let (accounts, transactions, unitOfWork, account) = try await openAccount()
        let total = try Transaction.make(accountID: account.id, amount: 30)
        let split = try Transaction.make(accountID: account.id, amount: 20, type: .split(UUID()))
        let plain = try Transaction.make(accountID: account.id, amount: 10)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: [split, plain])
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenPartIsSplitPart() async throws {
        let (accounts, transactions, unitOfWork, account) = try await openAccount()
        let total = try Transaction.make(accountID: account.id, amount: 30)
        let nested = try Transaction.make(
            accountID: account.id,
            amount: 20,
            type: .splitPart(UUID(), .standard)
        )
        let plain = try Transaction.make(accountID: account.id, amount: 10)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: [nested, plain])
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenAmountsDiffer() async throws {
        let (accounts, transactions, unitOfWork, account) = try await openAccount()
        let total = try Transaction.make(accountID: account.id, amount: 30)
        let parts = try standardParts(accountID: account.id, amounts: [20, 5])

        await #expect(throws: ApplicationError.cannotExecute) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: parts)
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    // MARK: Errors

    @Test func failsWhenMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let total = try Transaction.make(amount: 30)
        let parts = try standardParts(accountID: total.accountID, amounts: [20, 10])

        await #expect(throws: AccountError.notFound) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: parts)
        }
        #expect(await transactions.all().isEmpty)
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        await accounts.delete(try account.delete())
        let total = try Transaction.make(accountID: account.id, amount: 30)
        let parts = try standardParts(accountID: account.id, amounts: [20, 10])

        await #expect(throws: AccountError.notFound) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: parts)
        }
        #expect(await transactions.all().isEmpty)
    }

    @Test func failsWhenClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let total = try Transaction.make(accountID: account.id, amount: 30)
        let parts = try standardParts(accountID: account.id, amounts: [20, 10])

        await #expect(throws: AccountError.closed) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: parts)
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func failsWhenTransferAccountIsMissing() async throws {
        let (accounts, transactions, unitOfWork, parent) = try await openAccount()
        let total = try Transaction.make(accountID: parent.id, amount: -30)
        let cash = try Transaction.make(accountID: parent.id, amount: -10)
        let card = try Transaction.make(accountID: UUID(), amount: -20, type: .transfer(UUID()))

        await #expect(throws: AccountError.notFound) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: [cash, card])
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: parent.id)?.balance == 0)
    }

    @Test func failsWhenTransferAccountIsClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let parent = try Account.make()
        let other = try Account.make(name: "Bank", isClosed: true)
        await accounts.save(parent)
        await accounts.save(other)
        let total = try Transaction.make(accountID: parent.id, amount: -30)
        let cash = try Transaction.make(accountID: parent.id, amount: -10)
        let card = try Transaction.make(accountID: other.id, amount: -20, type: .transfer(UUID()))

        await #expect(throws: AccountError.closed) {
            try await AddSplit(unitOfWork: unitOfWork).execute(total, parts: [cash, card])
        }
        #expect(await transactions.all().isEmpty)
        #expect(try await accounts.query(id: parent.id)?.balance == 0)
        #expect(try await accounts.query(id: other.id)?.balance == 0)
    }

    private func standardParts(accountID: UUID, amounts: [Decimal]) throws -> [Transaction] {
        try amounts.map { amount in
            try Transaction.make(accountID: accountID, amount: amount)
        }
    }

    private func openAccount() async throws -> (
        InMemoryAccountRepository,
        InMemoryTransactionRepository,
        InMemoryUnitOfWork,
        Account
    ) {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        return (accounts, transactions, unitOfWork, account)
    }
}
