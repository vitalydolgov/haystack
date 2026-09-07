import Foundation
import Testing
@testable import Haystack

struct EditAccountTests {
    @Test func persistsNameNotesAndWorkingBalance() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(type: .debitCard, notes: "Pocket cash")
        await accounts.save(account)
        await transactions.save(try Transaction.make(accountID: account.id, amount: 42))

        try await EditAccount(unitOfWork: unitOfWork).execute(
            id: account.id,
            name: "  Cash  ",
            notes: "On hand",
            workingBalance: 10
        )
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.name == "Cash")
        #expect(stored.notes == "On hand")
        #expect(stored.balance(await transactions.find(accountID: stored.id)) == 10)
    }

    @Test func persistsNameAndNotesWhenClosedWithoutChangingBalance() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(type: .savings, notes: "Pocket cash", isClosed: true)
        await accounts.save(account)

        try await EditAccount(unitOfWork: unitOfWork).execute(
            id: account.id,
            name: "Old Wallet",
            notes: "Retired",
            workingBalance: 10
        )
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.name == "Old Wallet")
        #expect(stored.notes == "Retired")
        #expect(stored.balance(await transactions.find(accountID: stored.id)) == 0)
    }

    @Test func doesNotRecordAnAdjustmentWhenWorkingBalanceIsUnchanged() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)
        await transactions.save(try Transaction.make(accountID: account.id, amount: 42))

        try await EditAccount(unitOfWork: unitOfWork).execute(
            id: account.id,
            name: "Cash",
            notes: "On hand",
            workingBalance: 42
        )
        let recorded = await transactions.find(accountID: account.id)
        #expect(recorded.count == 1)
        #expect(recorded.map(\.type) == [.standard])
    }

    // MARK: Validation

    @Test(arguments: ["Wallet", "  Wallet  "])
    func allowsSaveWhenNameIsPresent(name: String) {
        #expect(EditAccount.canExecute(name: name))
    }

    @Test(arguments: ["", "   "])
    func doesNotAllowSaveWhenNameIsBlank(name: String) {
        #expect(!EditAccount.canExecute(name: name))
    }

    // MARK: Errors

    @Test func doesNotPersistWhenNameIsBlank() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(type: .debitCard, notes: "Pocket cash")
        await accounts.save(account)
        await transactions.save(try Transaction.make(accountID: account.id, amount: 42))

        await #expect(throws: AccountError.blankName) {
            try await EditAccount(unitOfWork: unitOfWork).execute(
                id: account.id,
                name: "   ",
                notes: "changed",
                workingBalance: 10
            )
        }
        let stored = try #require(await accounts.find(id: account.id))
        #expect(stored.name == "Wallet")
        #expect(stored.notes == "Pocket cash")
        #expect(stored.balance(await transactions.find(accountID: stored.id)) == 42)
    }

    @Test func failsWhenMissing() async {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        await #expect(throws: AccountError.notFound) {
            try await EditAccount(unitOfWork: unitOfWork).execute(
                id: UUID(),
                name: "Wallet",
                notes: "",
                workingBalance: 0
            )
        }
    }

    @Test func failsWhenDeleted() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make(isClosed: true)
        await accounts.save(account)
        let deleted = try account.delete()
        await accounts.delete(deleted)

        await #expect(throws: AccountError.notFound) {
            try await EditAccount(unitOfWork: unitOfWork).execute(
                id: account.id,
                name: "Cash",
                notes: "changed",
                workingBalance: 0
            )
        }
    }
}
