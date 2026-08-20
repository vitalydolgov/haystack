import Foundation
import Testing
@testable import Haystack

struct AdjustBalanceTests {
    // MARK: - Persist

    @Test func persistsNewBalance() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(type: .debitCard, notes: "Pocket cash")
        await accounts.save(account)

        try await AdjustBalance(accounts: accounts).execute(id: account.id, to: 25)
        let stored = try #require(await accounts.find(id: account.id))

        #expect(stored.name == "Wallet")
        #expect(stored.type == .debitCard)
        #expect(stored.notes == "Pocket cash")
        #expect(stored.balance == 25)
        #expect(stored.isClosed == false)
    }

    // MARK: - Errors

    @Test func failsWhenClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(type: .debitCard, notes: "Retired", isClosed: true)
        await accounts.save(account)

        await #expect(throws: AccountError.closed) {
            try await AdjustBalance(accounts: accounts).execute(id: account.id, to: 10)
        }
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.name == "Wallet")
        #expect(stored.type == .debitCard)
        #expect(stored.notes == "Retired")
        #expect(stored.balance == 0)
        #expect(stored.isClosed == true)
    }

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        await #expect(throws: AccountError.notFound) {
            try await AdjustBalance(accounts: accounts).execute(id: UUID(), to: 0)
        }
    }
}
