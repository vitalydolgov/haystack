import Foundation
import Testing
@testable import Haystack

struct AddTransferTests {
    @Test func createsTwoTransferLegs() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make()
        let toAccount = try Account.make()
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let (fromLeg, toLeg) = try await AddTransfer(unitOfWork: unitOfWork).execute(
            fromAccountID: fromAccount.id,
            toAccountID: toAccount.id,
            date: date,
            magnitude: 12.5,
            notes: "Gift"
        )

        #expect(fromLeg.accountID == fromAccount.id)
        #expect(fromLeg.amount == -12.5)
        #expect(fromLeg.type.transferID != nil)
        #expect(fromLeg.notes == "Gift")
        #expect(fromLeg.type.transferID == toLeg.type.transferID)

        #expect(toLeg.accountID == toAccount.id)
        #expect(toLeg.amount == 12.5)
        #expect(toLeg.type.transferID != nil)
        #expect(toLeg.type.transferID == fromLeg.type.transferID)

        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        #expect(fromLeg.date == (year: components.year!, month: components.month!, day: components.day!))
        #expect(toLeg.date == (year: components.year!, month: components.month!, day: components.day!))
        #expect(try await accounts.query(id: fromAccount.id)?.balance == -12.5)
        #expect(try await accounts.query(id: toAccount.id)?.balance == 12.5)
    }

    // MARK: Errors

    @Test func failsWhenSameAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let account = try Account.make()
        await accounts.save(account)

        await #expect(throws: TransferError.sameAccount) {
            try await AddTransfer(unitOfWork: unitOfWork).execute(
                fromAccountID: account.id,
                toAccountID: account.id,
                magnitude: 10
            )
        }
        #expect(await transactions.all().isEmpty)
    }

    @Test func failsWhenFromAccountMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let toAccount = try Account.make()
        await accounts.save(toAccount)

        await #expect(throws: AccountError.notFound) {
            try await AddTransfer(unitOfWork: unitOfWork).execute(
                fromAccountID: UUID(),
                toAccountID: toAccount.id,
                magnitude: 10
            )
        }
        #expect(await transactions.all().isEmpty)
    }

    @Test func failsWhenToAccountMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make()
        await accounts.save(fromAccount)

        await #expect(throws: AccountError.notFound) {
            try await AddTransfer(unitOfWork: unitOfWork).execute(
                fromAccountID: fromAccount.id,
                toAccountID: UUID(),
                magnitude: 10
            )
        }
        #expect(await transactions.all().isEmpty)
    }

    @Test func failsWhenFromAccountClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(isClosed: true)
        await accounts.save(fromAccount)
        let toAccount = try Account.make()
        await accounts.save(toAccount)

        await #expect(throws: AccountError.closed) {
            try await AddTransfer(unitOfWork: unitOfWork).execute(
                fromAccountID: fromAccount.id,
                toAccountID: toAccount.id,
                magnitude: 10
            )
        }
        #expect(await transactions.all().isEmpty)
    }

    @Test func failsWhenToAccountClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make()
        await accounts.save(fromAccount)
        let toAccount = try Account.make(isClosed: true)
        await accounts.save(toAccount)

        await #expect(throws: AccountError.closed) {
            try await AddTransfer(unitOfWork: unitOfWork).execute(
                fromAccountID: fromAccount.id,
                toAccountID: toAccount.id,
                magnitude: 10
            )
        }
        #expect(await transactions.all().isEmpty)
    }

    // MARK: Can execute

    @Test func allowsSaveWhenAccountsDifferAndMagnitudeIsPositive() {
        #expect(AddTransfer.canExecute(fromAccountID: UUID(), toAccountID: UUID(), magnitude: 1))
    }

    @Test func doesNotAllowSaveWhenAccountsMatch() {
        let accountID = UUID()
        #expect(!AddTransfer.canExecute(fromAccountID: accountID, toAccountID: accountID, magnitude: 1))
    }

    @Test func doesNotAllowSaveWhenMagnitudeIsZero() {
        #expect(!AddTransfer.canExecute(fromAccountID: UUID(), toAccountID: UUID(), magnitude: 0))
    }

    @Test func doesNotAllowSaveWhenMagnitudeIsNegative() {
        #expect(!AddTransfer.canExecute(fromAccountID: UUID(), toAccountID: UUID(), magnitude: -1))
    }
}
