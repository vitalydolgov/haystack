import Foundation
import Testing
@testable import Haystack

struct ConvertTransferToTransactionTests {
    @Test func keepsLegOnGivenAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(name: "Wallet")
        let toAccount = try Account.make(name: "Savings", type: .savings)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -12.5,
            notes: "Gift",
            type: .transfer,
            transferID: transferID
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 12.5,
            notes: "Gift",
            type: .transfer,
            transferID: transferID
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try await ConvertTransferToTransaction(unitOfWork: unitOfWork).execute(
            transferID: transferID,
            keeping: fromAccount.id,
            date: date,
            amount: -20,
            notes: "Coffee"
        )

        let stored = try #require(await transactions.find(id: fromLeg.id))
        #expect(stored.accountID == fromAccount.id)
        #expect(stored.type == .standard)
        #expect(stored.transferID == nil)
        #expect(stored.amount == -20)
        #expect(stored.notes == "Coffee")
        #expect(stored.date == date.asYearMonthDay())

        #expect(await transactions.find(id: toLeg.id) == nil)
        #expect(await transactions.deleted(id: toLeg.id) != nil)
        #expect(await transactions.all().count == 1)
    }

    @Test func keepsInflowLeg() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(name: "Wallet")
        let toAccount = try Account.make(name: "Savings", type: .savings)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -12.5,
            type: .transfer,
            transferID: transferID
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 12.5,
            type: .transfer,
            transferID: transferID
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        try await ConvertTransferToTransaction(unitOfWork: unitOfWork).execute(
            transferID: transferID,
            keeping: toAccount.id,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            amount: 12.5
        )

        let stored = try #require(await transactions.find(id: toLeg.id))
        #expect(stored.accountID == toAccount.id)
        #expect(stored.type == .standard)
        #expect(stored.transferID == nil)
        #expect(await transactions.find(id: fromLeg.id) == nil)
    }

    @Test func movesKeptLegWhenAccountDiffers() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(name: "Wallet")
        let toAccount = try Account.make(name: "Savings", type: .savings)
        let targetAccount = try Account.make(name: "Checking", type: .debitCard)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        await accounts.save(targetAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -12.5,
            type: .transfer,
            transferID: transferID
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 12.5,
            type: .transfer,
            transferID: transferID
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        try await ConvertTransferToTransaction(unitOfWork: unitOfWork).execute(
            transferID: transferID,
            keeping: fromAccount.id,
            movingTo: targetAccount.id,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            amount: -12.5
        )

        let stored = try #require(await transactions.find(id: fromLeg.id))
        #expect(stored.accountID == targetAccount.id)
        #expect(stored.type == .standard)
        #expect(await transactions.find(id: toLeg.id) == nil)
    }

    // MARK: Errors

    @Test func failsWhenTransferMissing() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)

        await #expect(throws: TransferError.notFound) {
            try await ConvertTransferToTransaction(unitOfWork: unitOfWork).execute(
                transferID: UUID(),
                keeping: UUID(),
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: 10
            )
        }
    }

    @Test func failsWhenAccountIsNotPartOfTransfer() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let other = try Account.make(name: "Other")
        await accounts.save(other)
        let transferID = UUID()
        let fromLeg = try Transaction.make(amount: -10, type: .transfer, transferID: transferID)
        let toLeg = try Transaction.make(amount: 10, type: .transfer, transferID: transferID)
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: TransactionError.notFound) {
            try await ConvertTransferToTransaction(unitOfWork: unitOfWork).execute(
                transferID: transferID,
                keeping: other.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: 10
            )
        }
        #expect(await transactions.find(id: fromLeg.id)?.type == .transfer)
        #expect(await transactions.find(id: toLeg.id)?.type == .transfer)
    }

    @Test func failsWhenAccountIsMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let accountID = UUID()
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: accountID,
            amount: -10,
            type: .transfer,
            transferID: transferID
        )
        let toLeg = try Transaction.make(amount: 10, type: .transfer, transferID: transferID)
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: AccountError.notFound) {
            try await ConvertTransferToTransaction(unitOfWork: unitOfWork).execute(
                transferID: transferID,
                keeping: accountID,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -10
            )
        }
        #expect(await transactions.all().count == 2)
    }

    @Test func failsWhenAccountIsClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
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

        await #expect(throws: AccountError.closed) {
            try await ConvertTransferToTransaction(unitOfWork: unitOfWork).execute(
                transferID: transferID,
                keeping: account.id,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                amount: -10
            )
        }
        #expect(await transactions.find(id: fromLeg.id)?.transferID == transferID)
        #expect(await transactions.find(id: toLeg.id)?.transferID == transferID)
    }
}
