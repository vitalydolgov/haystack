import Foundation
import Testing
@testable import Haystack

struct ReplaceTransferTests {
    @Test func replacesBothLegs() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(name: "Wallet", balance: -10)
        let toAccount = try Account.make(name: "Savings", type: .savings, balance: 10)
        let nextAccount = try Account.make(name: "Credit")
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        await accounts.save(nextAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
            id: transferID,
            fromAccountID: nextAccount.id,
            toAccountID: toAccount.id,
            date: date,
            amount: 40,
            notes: "Rent"
        )

        #expect(await transactions.query(id: fromLeg.id) == nil)
        #expect(await transactions.query(id: toLeg.id) == nil)
        let legs = await transactions.all()
        let outflow = try #require(legs.first { $0.amount < 0 })
        let inflow = try #require(legs.first { $0.amount > 0 })
        #expect(legs.count == 2)
        #expect(outflow.accountID == nextAccount.id)
        #expect(outflow.amount == -40)
        #expect(outflow.notes == "Rent")
        #expect(outflow.date == date.asYearMonthDay())
        #expect(outflow.type.transferID != nil)
        #expect(inflow.accountID == toAccount.id)
        #expect(inflow.amount == 40)
        #expect(inflow.notes == "Rent")
        #expect(inflow.date == date.asYearMonthDay())
        #expect(inflow.type.transferID != nil)
        #expect(outflow.type.transferID == inflow.type.transferID)
        #expect(outflow.type.transferID != transferID)
        #expect(try await accounts.query(id: fromAccount.id)?.balance == 0)
        #expect(try await accounts.query(id: toAccount.id)?.balance == 40)
        #expect(try await accounts.query(id: nextAccount.id)?.balance == -40)
    }

    // MARK: Can execute

    @Test func failsWhenAmountIsZero() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make()
        let toAccount = try Account.make(name: "Savings", type: .savings)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                fromAccountID: fromAccount.id,
                toAccountID: toAccount.id,
                date: .now,
                amount: 0
            )
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
    }

    @Test func failsWhenAmountIsNegative() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make()
        let toAccount = try Account.make(name: "Savings", type: .savings)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                fromAccountID: fromAccount.id,
                toAccountID: toAccount.id,
                date: .now,
                amount: -10
            )
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
    }

    @Test func failsWhenSameAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make()
        let toAccount = try Account.make(name: "Savings", type: .savings)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: ApplicationError.cannotExecute) {
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                fromAccountID: fromAccount.id,
                toAccountID: fromAccount.id,
                date: .now,
                amount: 10
            )
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
        #expect(await transactions.all().count == 2)
    }

    // MARK: Errors

    @Test func failsWhenNotFound() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make()
        let toAccount = try Account.make(name: "Savings", type: .savings)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)

        await #expect(throws: TransferError.notFound) {
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: UUID(),
                fromAccountID: fromAccount.id,
                toAccountID: toAccount.id,
                date: .now,
                amount: 10
            )
        }
        #expect(await transactions.all().isEmpty)
    }

    @Test func failsWhenOutflowAccountMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let toAccount = try Account.make(name: "Savings", type: .savings, balance: 10)
        let nextAccount = try Account.make(name: "Credit")
        await accounts.save(toAccount)
        await accounts.save(nextAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(amount: -10, type: .transfer(transferID))
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: AccountError.notFound) {
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                fromAccountID: nextAccount.id,
                toAccountID: toAccount.id,
                date: .now,
                amount: 10
            )
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
    }

    @Test func failsWhenInflowAccountMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(balance: -10)
        let nextAccount = try Account.make(name: "Credit")
        await accounts.save(fromAccount)
        await accounts.save(nextAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(amount: 10, type: .transfer(transferID))
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: AccountError.notFound) {
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                fromAccountID: nextAccount.id,
                toAccountID: fromAccount.id,
                date: .now,
                amount: 10
            )
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
    }

    @Test func failsWhenFromAccountMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(balance: -10)
        let toAccount = try Account.make(name: "Savings", type: .savings, balance: 10)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: AccountError.notFound) {
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                fromAccountID: UUID(),
                toAccountID: toAccount.id,
                date: .now,
                amount: 10
            )
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
    }

    @Test func failsWhenToAccountMissing() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(balance: -10)
        let toAccount = try Account.make(name: "Savings", type: .savings, balance: 10)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: AccountError.notFound) {
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                fromAccountID: fromAccount.id,
                toAccountID: UUID(),
                date: .now,
                amount: 10
            )
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
    }

    @Test func failsWhenFromAccountClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(balance: -10)
        let toAccount = try Account.make(name: "Savings", type: .savings, balance: 10)
        let nextAccount = try Account.make(name: "Credit", isClosed: true)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        await accounts.save(nextAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: AccountError.closed) {
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                fromAccountID: nextAccount.id,
                toAccountID: toAccount.id,
                date: .now,
                amount: 10
            )
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
    }

    @Test func failsWhenToAccountClosed() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make(balance: -10)
        let toAccount = try Account.make(name: "Savings", type: .savings, balance: 10)
        let nextAccount = try Account.make(name: "Credit", isClosed: true)
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        await accounts.save(nextAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: AccountError.closed) {
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                fromAccountID: fromAccount.id,
                toAccountID: nextAccount.id,
                date: .now,
                amount: 10
            )
        }
        #expect(await transactions.query(id: fromLeg.id) != nil)
        #expect(await transactions.query(id: toLeg.id) != nil)
    }
}
