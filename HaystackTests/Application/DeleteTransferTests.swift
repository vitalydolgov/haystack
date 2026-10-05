import Foundation
import Testing
@testable import Haystack

struct DeleteTransferTests {
    @Test func deletesBothLegs() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(balance: -10)
        let toAccount = try Account.make(balance: 10)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await DeleteTransfer(unitOfWork: unitOfWork).execute(id: transferID, at: deletedAt)

        #expect(await transactions.query(id: fromLeg.id) == nil)
        #expect(await transactions.query(id: toLeg.id) == nil)
        #expect(await transactions.deleted(id: fromLeg.id)?.deletedAt == deletedAt)
        #expect(await transactions.deleted(id: toLeg.id)?.deletedAt == deletedAt)
        #expect(try await accounts.query(id: fromAccount.id)?.balance == 0)
        #expect(try await accounts.query(id: toAccount.id)?.balance == 0)
    }

    // MARK: Errors

    @Test func failsWhenNotFound() async {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)

        await #expect(throws: TransferError.notFound) {
            try await DeleteTransfer(unitOfWork: unitOfWork).execute(id: UUID())
        }
    }

    @Test func failsWhenFromAccountMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let toAccount = try Account.make(balance: 10)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: AccountError.notFound) {
            try await DeleteTransfer(unitOfWork: unitOfWork).execute(id: transferID)
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
        #expect(try await accounts.query(id: toAccount.id)?.balance == 10)
    }

    @Test func failsWhenToAccountMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(balance: -10)
        await accounts.save(fromAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: AccountError.notFound) {
            try await DeleteTransfer(unitOfWork: unitOfWork).execute(id: transferID)
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
        #expect(try await accounts.query(id: fromAccount.id)?.balance == -10)
    }
}
