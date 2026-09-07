import Foundation
import Testing
@testable import Haystack

struct ReopenAccountTests {
    @Test func persistsOpenState() async throws {
        let accounts = InMemoryAccountRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)

        try await ReopenAccount(unitOfWork: unitOfWork).execute(id: account.id)
        let stored = try #require(await accounts.find(id: account.id))
        #expect(!stored.isClosed)
    }

    @Test func doesNotChangeAnAlreadyOpenAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts)
        let account = try Account.make()
        await accounts.save(account)

        try await ReopenAccount(unitOfWork: unitOfWork).execute(id: account.id)
        let stored = try #require(await accounts.find(id: account.id))
        #expect(!stored.isClosed)
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts)
        await #expect(throws: AccountError.notFound) {
            try await ReopenAccount(unitOfWork: unitOfWork).execute(id: UUID())
        }
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let deleted = try account.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        await accounts.delete(deleted)

        await #expect(throws: AccountError.notFound) {
            try await ReopenAccount(unitOfWork: unitOfWork).execute(id: account.id)
        }
    }
}
