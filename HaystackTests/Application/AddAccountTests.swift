import Foundation
import Testing
@testable import Haystack

struct AddAccountTests {
    @Test func persistsTheAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let added = try await AddAccount(accounts: accounts, transactions: transactions).execute(
            name: "  Wallet  ",
            type: .cash,
            notes: "Pocket cash",
            balance: 42
        )
        let stored = try #require(await accounts.find(id: added.id))

        #expect(stored.name == "Wallet")
        #expect(stored.type == .cash)
        #expect(stored.notes == "Pocket cash")
        #expect(stored.balance(await transactions.find(accountID: stored.id)) == 42)
    }

    @Test func recordsAnAdjustmentWhenBalanceIsNonZero() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let added = try await AddAccount(accounts: accounts, transactions: transactions).execute(
            name: "Wallet",
            type: .cash,
            balance: 42
        )

        let recorded = await transactions.find(accountID: added.id)
        #expect(recorded.map(\.type) == [.adjustment])
    }

    // MARK: Validation

    @Test(arguments: [
        ("Wallet", AccountType.cash as AccountType?, Decimal?.some(0)),
        ("  Wallet  ", AccountType.cash as AccountType?, Decimal?.some(0)),
    ])
    func allowsSaveWhenRequiredFieldsArePresent(
        name: String,
        type: AccountType?,
        balance: Decimal?
    ) {
        #expect(AddAccount.canExecute(name: name, type: type, balance: balance))
    }

    @Test(arguments: [
        ("", AccountType.cash as AccountType?, Decimal?.some(0)),
        ("   ", AccountType.cash as AccountType?, Decimal?.some(0)),
        ("Wallet", nil, Decimal?.some(0)),
        ("Wallet", AccountType.cash as AccountType?, nil),
    ])
    func doesNotAllowSaveWhenARequiredFieldIsMissing(
        name: String,
        type: AccountType?,
        balance: Decimal?
    ) {
        #expect(!AddAccount.canExecute(name: name, type: type, balance: balance))
    }

    // MARK: Errors

    @Test func doesNotPersistWhenNameIsBlank() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        await #expect(throws: AccountError.blankName) {
            try await AddAccount(accounts: accounts, transactions: transactions).execute(
                name: "   ",
                type: .cash,
                notes: "Pocket cash",
                balance: 42
            )
        }
        #expect(await accounts.all().isEmpty)
    }
}
