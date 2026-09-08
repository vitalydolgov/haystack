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
            amount: 12.5,
            notes: "Gift"
        )

        #expect(fromLeg.accountID == fromAccount.id)
        #expect(fromLeg.amount == -12.5)
        #expect(fromLeg.type == .transfer)
        #expect(fromLeg.notes == "Gift")
        #expect(fromLeg.transferID == toLeg.transferID)

        #expect(toLeg.accountID == toAccount.id)
        #expect(toLeg.amount == 12.5)
        #expect(toLeg.type == .transfer)
        #expect(toLeg.transferID == fromLeg.transferID)

        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        #expect(fromLeg.date == (year: components.year!, month: components.month!, day: components.day!))
        #expect(toLeg.date == (year: components.year!, month: components.month!, day: components.day!))
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
                amount: 10
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
                amount: 10
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
                amount: 10
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
                amount: 10
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
                amount: 10
            )
        }
        #expect(await transactions.all().isEmpty)
    }
}
