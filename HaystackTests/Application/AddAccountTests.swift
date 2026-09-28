import Foundation
import Testing
@testable import Haystack

struct AddAccountTests {
    @Test func persistsTheAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let added = try await AddAccount(unitOfWork: unitOfWork).execute(
            name: "  Wallet  ",
            type: .cash,
            notes: "Pocket cash",
            balance: 42
        )
        let stored = try #require(try await accounts.query(id: added.id))

        #expect(stored.name == "Wallet")
        #expect(stored.type == .cash)
        #expect(stored.notes == "Pocket cash")
        #expect(stored.balance(await transactions.query(.account(stored.id))) == 42)
    }

    @Test func recordsAnAdjustmentWhenBalanceIsNonZero() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let added = try await AddAccount(unitOfWork: unitOfWork).execute(
            name: "Wallet",
            type: .cash,
            balance: 42
        )

        let recorded = await transactions.query(.account(added.id))
        #expect(recorded.map(\.type) == [.adjustment])
    }

    @Test func doesNotRecordAnAdjustmentWhenBalanceIsZero() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let added = try await AddAccount(unitOfWork: unitOfWork).execute(
            name: "Wallet",
            type: .cash
        )

        #expect(await transactions.query(.account(added.id)).isEmpty)
    }

    // MARK: Validation

    @Test(arguments: ["Wallet", "  Wallet  "])
    func allowsSaveWhenNameIsPresent(name: String) {
        #expect(AddAccount.canExecute(name: name))
    }

    @Test(arguments: ["", "   "])
    func doesNotAllowSaveWhenNameIsBlank(name: String) {
        #expect(!AddAccount.canExecute(name: name))
    }

    // MARK: Errors

    @Test func doesNotPersistWhenNameIsBlank() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        await #expect(throws: AccountError.blankName) {
            try await AddAccount(unitOfWork: unitOfWork).execute(
                name: "   ",
                type: .cash,
                notes: "Pocket cash",
                balance: 42
            )
        }
        #expect(await accounts.all().isEmpty)
    }
}
