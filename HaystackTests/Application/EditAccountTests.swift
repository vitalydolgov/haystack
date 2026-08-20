import Foundation
import Testing
@testable import Haystack

struct EditAccountTests {
    // MARK: - Persist

    @Test func persistsNameNotesAndWorkingBalance() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(type: .debitCard, notes: "Pocket cash", balance: 42)
        await accounts.save(account)

        try await EditAccount(accounts: accounts).execute(
            id: account.id,
            name: "  Cash  ",
            notes: "On hand",
            workingBalance: 10
        )
        let stored = try #require(await accounts.find(id: account.id))

        #expect(stored.name == "Cash")
        #expect(stored.type == .debitCard)
        #expect(stored.notes == "On hand")
        #expect(stored.balance == 10)
        #expect(stored.isClosed == false)
    }

    @Test func persistsNameAndNotesWhenClosedWithoutChangingBalance() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(type: .savings, notes: "Pocket cash", isClosed: true)
        await accounts.save(account)

        try await EditAccount(accounts: accounts).execute(
            id: account.id,
            name: "Old Wallet",
            notes: "Retired",
            workingBalance: 10
        )
        let stored = try #require(await accounts.find(id: account.id))

        #expect(stored.name == "Old Wallet")
        #expect(stored.type == .savings)
        #expect(stored.notes == "Retired")
        #expect(stored.balance == 0)
        #expect(stored.isClosed == true)
    }

    // MARK: - Errors

    @Test func doesNotPersistWhenNameIsBlank() async throws {
        let accounts = InMemoryAccountRepository()
        let account = try Account.make(type: .debitCard, notes: "Pocket cash", balance: 42)
        await accounts.save(account)

        await #expect(throws: AccountError.blankName) {
            try await EditAccount(accounts: accounts).execute(
                id: account.id,
                name: "   ",
                notes: "changed",
                workingBalance: 10
            )
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
            try await EditAccount(accounts: accounts).execute(
                id: UUID(),
                name: "Wallet",
                notes: "",
                workingBalance: 0
            )
        }
    }

    // MARK: - canExecute

    @Test(arguments: [
        ("Wallet", Decimal?.some(0), false),
        ("  Wallet  ", Decimal?.some(0), false),
        ("Wallet", nil, true),
        ("Wallet", Decimal?.some(0), true),
    ])
    func allowsSaveWhenRequiredFieldsArePresent(
        name: String,
        workingBalance: Decimal?,
        isClosed: Bool
    ) {
        #expect(EditAccount.canExecute(name: name, workingBalance: workingBalance, isClosed: isClosed))
    }

    @Test(arguments: [
        ("", Decimal?.some(0), false),
        ("   ", Decimal?.some(0), false),
        ("Wallet", nil, false),
        ("", nil, true),
        ("   ", nil, true),
    ])
    func doesNotAllowSaveWhenARequiredFieldIsMissing(
        name: String,
        workingBalance: Decimal?,
        isClosed: Bool
    ) {
        #expect(!EditAccount.canExecute(name: name, workingBalance: workingBalance, isClosed: isClosed))
    }
}
