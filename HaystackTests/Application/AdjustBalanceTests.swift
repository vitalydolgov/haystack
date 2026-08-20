import Foundation
import Testing
@testable import Haystack

struct AdjustBalanceTests {
    @Test func persistsNewBalance() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make()
        await accounts.save(account)

        try await AdjustBalance(accounts: accounts).execute(id: account.id, to: 25)
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.balance == 25)
    }

    // MARK: Errors

    @Test func failsWhenClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)

        await #expect(throws: AccountError.closed) {
            try await AdjustBalance(accounts: accounts).execute(id: account.id, to: 10)
        }
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.balance == 0)
    }

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        await #expect(throws: AccountError.notFound) {
            try await AdjustBalance(accounts: accounts).execute(id: UUID(), to: 0)
        }
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let deleted = try account.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        await accounts.delete(deleted)

        await #expect(throws: AccountError.notFound) {
            try await AdjustBalance(accounts: accounts).execute(id: account.id, to: 10)
        }
    }
}
