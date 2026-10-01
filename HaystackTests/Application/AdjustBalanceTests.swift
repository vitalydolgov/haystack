import Foundation
import Testing
@testable import Haystack

struct AdjustBalanceTests {
    @Test func persistsNewBalance() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)

        _ = try await AdjustBalance(unitOfWork: unitOfWork)
            .execute(id: account.id, to: 25)
        let stored = try #require(try await accounts.query(id: account.id))
        #expect(stored.balance(await transactions.query(.account(stored.id))) == 25)
        #expect(stored.balance == 25)
    }

    @Test func recordsAnAdjustment() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)

        _ = try await AdjustBalance(unitOfWork: unitOfWork)
            .execute(id: account.id, to: 25)

        let recorded = await transactions.query(.account(account.id))
        #expect(recorded.map(\.type) == [.standard])
    }

    // MARK: Errors

    @Test func failsWhenAlreadyAtTarget() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(balance: 25)
        await accounts.save(account)
        await transactions.save(try Transaction.make(accountID: account.id, amount: 25))

        await #expect(throws: TransactionError.invalidAmount) {
            try await AdjustBalance(unitOfWork: unitOfWork)
                .execute(id: account.id, to: 25)
        }
        let recorded = await transactions.query(.account(account.id))
        #expect(recorded.count == 1)
        #expect(recorded.map(\.type) == [.standard])
    }

    @Test func failsWhenClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)

        await #expect(throws: AccountError.closed) {
            try await AdjustBalance(unitOfWork: unitOfWork)
                .execute(id: account.id, to: 10)
        }
        let stored = try #require(try await accounts.query(id: account.id))
        #expect(stored.balance(await transactions.query(.account(stored.id))) == 0)
    }

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        await #expect(throws: AccountError.notFound) {
            try await AdjustBalance(unitOfWork: unitOfWork)
                .execute(id: UUID(), to: 0)
        }
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let deleted = try account.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        await accounts.delete(deleted)

        await #expect(throws: AccountError.notFound) {
            try await AdjustBalance(unitOfWork: unitOfWork)
                .execute(id: account.id, to: 10)
        }
    }
}
