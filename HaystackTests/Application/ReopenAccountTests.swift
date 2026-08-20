import Foundation
import Testing
@testable import Haystack

struct ReopenAccountTests {
    // MARK: - Persist

    @Test func persistsOpenState() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(type: .savings, notes: "Retired", isClosed: true)
        await accounts.save(account)

        try await ReopenAccount(accounts: accounts).execute(id: account.id)
        let stored = try #require(await accounts.find(id: account.id))

        #expect(stored.name == "Wallet")
        #expect(stored.type == .savings)
        #expect(stored.notes == "Retired")
        #expect(stored.balance == 0)
        #expect(stored.isClosed == false)
    }

    @Test func doesNotChangeAnAlreadyOpenAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(type: .debitCard, notes: "Pocket cash", balance: 42)
        await accounts.save(account)

        try await ReopenAccount(accounts: accounts).execute(id: account.id)
        let stored = try #require(await accounts.find(id: account.id))

        #expect(stored.name == "Wallet")
        #expect(stored.type == .debitCard)
        #expect(stored.notes == "Pocket cash")
        #expect(stored.balance == 42)
        #expect(stored.isClosed == false)
    }

    // MARK: - Errors

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        await #expect(throws: AccountError.notFound) {
            try await ReopenAccount(accounts: accounts).execute(id: UUID())
        }
    }
}
