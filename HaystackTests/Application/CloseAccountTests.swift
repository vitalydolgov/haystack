import Foundation
import Testing
@testable import Haystack

struct CloseAccountTests {
    // MARK: - Persist

    @Test func zeroesBalanceThenCloses() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(type: .debitCard, notes: "Pocket cash", balance: 25)
        await accounts.save(account)

        try await CloseAccount(accounts: accounts).execute(id: account.id)
        let stored = try #require(await accounts.find(id: account.id))

        #expect(stored.name == "Wallet")
        #expect(stored.type == .debitCard)
        #expect(stored.notes == "Pocket cash")
        #expect(stored.balance == 0)
        #expect(stored.isClosed == true)
    }

    @Test func doesNotChangeAnAlreadyClosedAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(type: .savings, notes: "Retired", isClosed: true)
        await accounts.save(account)

        try await CloseAccount(accounts: accounts).execute(id: account.id)
        let stored = try #require(await accounts.find(id: account.id))

        #expect(stored.name == "Wallet")
        #expect(stored.type == .savings)
        #expect(stored.notes == "Retired")
        #expect(stored.balance == 0)
        #expect(stored.isClosed == true)
    }

    // MARK: - Errors

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        await #expect(throws: AccountError.notFound) {
            try await CloseAccount(accounts: accounts).execute(id: UUID())
        }
    }
}
