import Foundation
import Testing
@testable import Haystack

struct CloseAccountTests {
    @Test func zeroesBalanceThenCloses() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(balance: 25)
        await accounts.save(account)

        try await CloseAccount(accounts: accounts).execute(id: account.id)
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.balance == 0)
        #expect(stored.isClosed)
    }

    @Test func doesNotChangeAnAlreadyClosedAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)

        try await CloseAccount(accounts: accounts).execute(id: account.id)
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.isClosed)
    }

    // MARK: Errors

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        await #expect(throws: AccountError.notFound) {
            try await CloseAccount(accounts: accounts).execute(id: UUID())
        }
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let deleted = try account.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        await accounts.delete(deleted)

        await #expect(throws: AccountError.notFound) {
            try await CloseAccount(accounts: accounts).execute(id: account.id)
        }
    }
}
