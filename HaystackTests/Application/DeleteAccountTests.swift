import Foundation
import Testing
@testable import Haystack

struct DeleteAccountTests {
    // MARK: - Persist

    @Test func removesAClosedAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(isClosed: true)
        await accounts.save(account)

        try await DeleteAccount(accounts: accounts).execute(id: account.id)
        #expect(await accounts.find(id: account.id) == nil)
    }

    // MARK: - Errors

    @Test func failsWhenOpen() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(type: .debitCard, notes: "Pocket cash", balance: 42)
        await accounts.save(account)

        await #expect(throws: AccountError.open) {
            try await DeleteAccount(accounts: accounts).execute(id: account.id)
        }
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.name == "Wallet")
        #expect(stored.type == .debitCard)
        #expect(stored.notes == "Pocket cash")
        #expect(stored.balance == 42)
        #expect(stored.isClosed == false)
    }

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        await #expect(throws: AccountError.notFound) {
            try await DeleteAccount(accounts: accounts).execute(id: UUID())
        }
    }
}
