import Foundation
import Testing
@testable import Haystack

struct DeleteSplitTests {
    @Test func deletesStandardParts() async throws {
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
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await DeleteSplit(unitOfWork: unitOfWork).execute(id: splitID, at: deletedAt)

        #expect(await transactions.query(id: total.id) == nil)
        #expect(await transactions.query(id: grocery.id) == nil)
        #expect(await transactions.query(id: tax.id) == nil)
        #expect(await transactions.deleted(id: total.id)?.deletedAt == deletedAt)
        #expect(await transactions.deleted(id: grocery.id)?.deletedAt == deletedAt)
        #expect(await transactions.deleted(id: tax.id)?.deletedAt == deletedAt)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func deletesSplitWithOnePart() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let account = try Account.make(balance: 10)
        await accounts.save(account)
        let total = try Transaction.make(
            id: splitID,
            accountID: account.id,
            amount: 10,
            type: .split(splitID)
        )
        let part = try Transaction.make(
            accountID: account.id,
            amount: 10,
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(total)
        await transactions.save(part)

        try await DeleteSplit(unitOfWork: unitOfWork).execute(id: splitID)

        #expect(await transactions.query(id: total.id) == nil)
        #expect(await transactions.query(id: part.id) == nil)
        #expect(try await accounts.query(id: account.id)?.balance == 0)
    }

    @Test func deletesTransferPart() async throws {
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
            type: .splitPart(splitID, .transfer(transferID))
        )
        let incoming = try Transaction.make(
            accountID: other.id,
            amount: 20,
            type: .transfer(transferID)
        )
        await transactions.save(total)
        await transactions.save(cash)
        await transactions.save(card)
        await transactions.save(incoming)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await DeleteSplit(unitOfWork: unitOfWork).execute(id: splitID, at: deletedAt)

        #expect(await transactions.query(id: total.id) == nil)
        #expect(await transactions.query(id: cash.id) == nil)
        #expect(await transactions.query(id: card.id) == nil)
        #expect(await transactions.query(id: incoming.id) == nil)
        #expect(await transactions.deleted(id: incoming.id)?.deletedAt == deletedAt)
        #expect(try await accounts.query(id: parent.id)?.balance == 0)
        #expect(try await accounts.query(id: other.id)?.balance == 0)
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)

        await #expect(throws: TransactionError.notFound) {
            try await DeleteSplit(unitOfWork: unitOfWork).execute(id: UUID())
        }
    }

    @Test func failsWhenAmountsDiffer() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let account = try Account.make(balance: 25)
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
            amount: 5,
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(total)
        await transactions.save(grocery)
        await transactions.save(tax)

        await #expect(throws: SplitError.invalidAmount) {
            try await DeleteSplit(unitOfWork: unitOfWork).execute(id: splitID)
        }
        #expect(await transactions.query(id: total.id) != nil)
        #expect(await transactions.query(id: grocery.id) != nil)
        #expect(await transactions.query(id: tax.id) != nil)
        #expect(try await accounts.query(id: account.id)?.balance == 25)
    }

    @Test func failsWhenPartAccountDiffers() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let account = try Account.make(balance: 10)
        let other = try Account.make(name: "Bank", balance: 10)
        await accounts.save(account)
        await accounts.save(other)
        let total = try Transaction.make(
            id: splitID,
            accountID: account.id,
            amount: 10,
            type: .split(splitID)
        )
        let part = try Transaction.make(
            accountID: other.id,
            amount: 10,
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(total)
        await transactions.save(part)

        await #expect(throws: SplitError.malformed) {
            try await DeleteSplit(unitOfWork: unitOfWork).execute(id: splitID)
        }
        #expect(await transactions.query(id: total.id) != nil)
        #expect(await transactions.query(id: part.id) != nil)
        #expect(try await accounts.query(id: account.id)?.balance == 10)
        #expect(try await accounts.query(id: other.id)?.balance == 10)
    }

    @Test func failsWhenAccountMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let accountID = UUID()
        let total = try Transaction.make(
            id: splitID,
            accountID: accountID,
            amount: 10,
            type: .split(splitID)
        )
        let part = try Transaction.make(
            accountID: accountID,
            amount: 10,
            type: .splitPart(splitID, .standard)
        )
        await transactions.save(total)
        await transactions.save(part)

        await #expect(throws: AccountError.notFound) {
            try await DeleteSplit(unitOfWork: unitOfWork).execute(id: splitID)
        }
        #expect(await transactions.query(id: total.id) != nil)
        #expect(await transactions.query(id: part.id) != nil)
    }

    @Test func failsWhenTransferNotFound() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let splitID = UUID()
        let account = try Account.make(balance: -30)
        await accounts.save(account)
        let total = try Transaction.make(
            id: splitID,
            accountID: account.id,
            amount: -30,
            type: .split(splitID)
        )
        let cash = try Transaction.make(
            accountID: account.id,
            amount: -10,
            type: .splitPart(splitID, .standard)
        )
        let card = try Transaction.make(
            accountID: account.id,
            amount: -20,
            type: .splitPart(splitID, .transfer(UUID()))
        )
        await transactions.save(total)
        await transactions.save(cash)
        await transactions.save(card)

        await #expect(throws: TransferError.notFound) {
            try await DeleteSplit(unitOfWork: unitOfWork).execute(id: splitID)
        }
        #expect(await transactions.query(id: total.id) != nil)
        #expect(await transactions.query(id: cash.id) != nil)
        #expect(await transactions.query(id: card.id) != nil)
        #expect(try await accounts.query(id: account.id)?.balance == -30)
    }
}
