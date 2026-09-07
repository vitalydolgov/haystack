import Foundation
import Testing
@testable import Haystack

struct DeleteAccountTests {
    @Test func marksAClosedAccountDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await DeleteAccount(unitOfWork: unitOfWork).execute(id: account.id, at: deletedAt)
        #expect(await accounts.find(id: account.id) == nil)

        let stored = try #require(await accounts.deleted(id: account.id))
        #expect(stored.deletedAt == deletedAt)
    }

    // MARK: Errors

    @Test func failsWhenOpen() async throws {
        let accounts = InMemoryAccountRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts)
        let account = try Account.make()
        await accounts.save(account)

        await #expect(throws: AccountError.open) {
            try await DeleteAccount(unitOfWork: unitOfWork).execute(id: account.id)
        }
        #expect(await accounts.find(id: account.id) != nil)
    }

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts)
        await #expect(throws: AccountError.notFound) {
            try await DeleteAccount(unitOfWork: unitOfWork).execute(id: UUID())
        }
    }

    @Test func failsWhenAlreadyDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try await DeleteAccount(unitOfWork: unitOfWork).execute(id: account.id, at: deletedAt)

        await #expect(throws: AccountError.notFound) {
            try await DeleteAccount(unitOfWork: unitOfWork).execute(id: account.id)
        }
        let stored = try #require(await accounts.deleted(id: account.id))
        #expect(stored.deletedAt == deletedAt)
    }
}
