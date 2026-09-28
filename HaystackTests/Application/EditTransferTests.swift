import Foundation
import Testing
@testable import Haystack

struct EditTransferTests {
    @Test func updatesDateAmountAndNotesOnBothLegs() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make()
        let toAccount = try Account.make()
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromAccountID = fromAccount.id
        let fromLeg = try Transaction.make(
            accountID: fromAccountID,
            amount: -10,
            notes: "Gift",
            type: .transfer,
            transferID: transferID
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            notes: "Gift",
            type: .transfer,
            transferID: transferID
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try await EditTransfer(unitOfWork: unitOfWork).execute(
            id: transferID,
            accountID: fromAccountID,
            date: date,
            amount: -20,
            notes: "Rent"
        )

        let storedFrom = try #require(await transactions.query(id: fromLeg.id))
        let storedTo = try #require(await transactions.query(id: toLeg.id))
        #expect(storedFrom.date == date.asYearMonthDay())
        #expect(storedFrom.amount == -20)
        #expect(storedFrom.notes == "Rent")
        #expect(storedTo.date == date.asYearMonthDay())
        #expect(storedTo.amount == 20)
        #expect(storedTo.notes == "Rent")
    }

    @Test func appliesAmountToGivenAccount() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make()
        let toAccount = try Account.make()
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let toAccountID = toAccount.id
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer,
            transferID: transferID
        )
        let toLeg = try Transaction.make(
            accountID: toAccountID,
            amount: 10,
            type: .transfer,
            transferID: transferID
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        try await EditTransfer(unitOfWork: unitOfWork).execute(
            id: transferID,
            accountID: toAccountID,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            amount: 30
        )

        #expect(await transactions.query(id: toLeg.id)?.amount == 30)
        #expect(await transactions.query(id: fromLeg.id)?.amount == -30)
    }

    // MARK: Validation

    @Test func allowsSaveWhenAmountIsNonZero() {
        #expect(EditTransfer.canExecute(amount: -1))
    }

    @Test func doesNotAllowSaveWhenAmountIsZero() {
        #expect(!EditTransfer.canExecute(amount: 0))
    }

    // MARK: Errors

    @Test func failsWhenAmountIsZero() async throws {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)
        let transferID = UUID()
        let fromLeg = try Transaction.make(amount: -10, type: .transfer, transferID: transferID)
        let toLeg = try Transaction.make(amount: 10, type: .transfer, transferID: transferID)
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: TransferError.invalidAmount) {
            try await EditTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                accountID: fromLeg.accountID,
                date: .now,
                amount: 0
            )
        }
        #expect(await transactions.query(id: fromLeg.id)?.amount == -10)
        #expect(await transactions.query(id: toLeg.id)?.amount == 10)
    }

    @Test func failsWhenNotFound() async {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)

        await #expect(throws: TransferError.notFound) {
            try await EditTransfer(unitOfWork: unitOfWork).execute(
                id: UUID(),
                accountID: UUID(),
                date: .now,
                amount: 10
            )
        }
    }

    @Test func failsWhenAccountIsNotPartOfTransfer() async throws {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)
        let transferID = UUID()
        let fromLeg = try Transaction.make(amount: -10, type: .transfer, transferID: transferID)
        let toLeg = try Transaction.make(amount: 10, type: .transfer, transferID: transferID)
        await transactions.save(fromLeg)
        await transactions.save(toLeg)

        await #expect(throws: TransactionError.notFound) {
            try await EditTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                accountID: UUID(),
                date: .now,
                amount: 10
            )
        }
        #expect(await transactions.query(id: fromLeg.id)?.amount == -10)
        #expect(await transactions.query(id: toLeg.id)?.amount == 10)
    }
}
