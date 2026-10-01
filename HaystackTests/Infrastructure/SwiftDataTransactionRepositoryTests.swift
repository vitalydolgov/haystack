import Foundation
import SwiftData
import Testing
@testable import Haystack

struct SwiftDataTransactionRepositoryTests {
    // MARK: Save

    @Test func roundTripsAllFields() async throws {
        let (container, writer) = try await makeStore()
        let accountID = UUID()
        let transaction = try Transaction.make(
            accountID: accountID,
            date: (year: 2024, month: 3, day: 15),
            amount: -42.5,
            notes: "Groceries",
            type: .standard
        )
        try await writer.save(transaction)

        let stored = try #require(try await reader(container).query(id: transaction.id))
        #expect(stored.id == transaction.id)
        #expect(stored.accountID == accountID)
        #expect(stored.date == (year: 2024, month: 3, day: 15))
        #expect(stored.amount == -42.5)
        #expect(stored.notes == "Groceries")
        #expect(stored.type == .standard)
        #expect(stored.type.transferID == nil)
    }

    @Test func updatesAnExistingTransactionInPlace() async throws {
        let (container, writer) = try await makeStore()
        var transaction = try Transaction.make(amount: 10, notes: "First")
        try await writer.save(transaction)

        try transaction.update(
            date: (year: 2025, month: 1, day: 2),
            amount: 20,
            notes: "Second"
        )
        try await writer.save(transaction)

        let stored = try #require(try await reader(container).query(id: transaction.id))
        #expect(stored.date == (year: 2025, month: 1, day: 2))
        #expect(stored.amount == 20)
        #expect(stored.notes == "Second")
    }

    @Test func storesTransactionsSeparately() async throws {
        let (_, transactions) = try await makeStore()
        let rent = try Transaction.make(amount: -100, notes: "Rent")
        let pay = try Transaction.make(amount: 200, notes: "Pay")
        try await transactions.save(rent)
        try await transactions.save(pay)

        #expect(try await transactions.query(id: rent.id)?.notes == "Rent")
        #expect(try await transactions.query(id: pay.id)?.notes == "Pay")
    }

    @Test func doesNotResurrectADeletedTransaction() async throws {
        let (_, transactions) = try await makeStore()
        let transaction = try Transaction.make()
        try await transactions.save(transaction)
        let deleted = transaction.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        try await transactions.delete(deleted)
        try await transactions.save(transaction)

        #expect(try await transactions.query(id: transaction.id) == nil)
    }

    // MARK: Save Batch

    @Test func savesEveryTransaction() async throws {
        let (_, transactions) = try await makeStore()
        let rent = try Transaction.make(amount: -100, notes: "Rent")
        let pay = try Transaction.make(amount: 200, notes: "Pay")
        try await transactions.save(batch: [rent, pay])

        #expect(try await transactions.query(id: rent.id)?.notes == "Rent")
        #expect(try await transactions.query(id: pay.id)?.notes == "Pay")
    }

    @Test func updatesStoredTransactions() async throws {
        let (_, transactions) = try await makeStore()
        let rent = try Transaction.make(notes: "Rent")
        let pay = try Transaction.make(notes: "Pay")
        try await transactions.save(batch: [rent, pay])
        let updatedRent = try Transaction.make(id: rent.id, accountID: rent.accountID, notes: "Rent paid")
        let updatedPay = try Transaction.make(id: pay.id, accountID: pay.accountID, notes: "Pay received")
        try await transactions.save(batch: [updatedRent, updatedPay])

        #expect(try await transactions.query(id: rent.id)?.notes == "Rent paid")
        #expect(try await transactions.query(id: pay.id)?.notes == "Pay received")
    }

    @Test func skipsDeletedTransaction() async throws {
        let (_, transactions) = try await makeStore()
        let deleted = try Transaction.make(notes: "Gone")
        try await transactions.save(deleted)
        try await transactions.delete(deleted.delete(at: Date(timeIntervalSince1970: 1_700_000_000)))
        let kept = try Transaction.make(notes: "Kept")
        try await transactions.save(batch: [deleted, kept])

        #expect(try await transactions.query(id: deleted.id) == nil)
        #expect(try await transactions.query(id: kept.id)?.notes == "Kept")
    }

    // MARK: Query

    @Test func findsALiveTransaction() async throws {
        let (container, writer) = try await makeStore()
        let transaction = try Transaction.make()
        try await writer.save(transaction)

        #expect(try await reader(container).query(id: transaction.id) != nil)
    }

    @Test func hidesADeletedTransaction() async throws {
        let (_, transactions) = try await makeStore()
        let transaction = try Transaction.make()
        try await transactions.save(transaction)
        let deleted = transaction.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        try await transactions.delete(deleted)

        #expect(try await transactions.query(id: transaction.id) == nil)
    }

    @Test func returnsNilWhenMissing() async throws {
        let (_, transactions) = try await makeStore()
        #expect(try await transactions.query(id: UUID()) == nil)
    }

    @Test func findsTransactionsForAnAccount() async throws {
        let (_, transactions) = try await makeStore()
        let accountID = UUID()
        let rent = try Transaction.make(accountID: accountID, amount: -100)
        try await transactions.save(rent)

        let found = try await transactions.query(.account(accountID))
        #expect(found.map(\.id) == [rent.id])
    }

    @Test func doesNotIncludeOtherAccounts() async throws {
        let (_, transactions) = try await makeStore()
        let accountID = UUID()
        let rent = try Transaction.make(accountID: accountID, amount: -100)
        let other = try Transaction.make(accountID: UUID(), amount: 50)
        try await transactions.save(rent)
        try await transactions.save(other)

        let found = try await transactions.query(.account(accountID))
        #expect(found.map(\.id) == [rent.id])
    }

    @Test func hidesDeletedWhenFindingByAccount() async throws {
        let (_, transactions) = try await makeStore()
        let accountID = UUID()
        let rent = try Transaction.make(accountID: accountID, amount: -100)
        try await transactions.save(rent)
        try await transactions.delete(rent.delete(at: Date(timeIntervalSince1970: 1_700_000_000)))

        #expect(try await transactions.query(.account(accountID)).isEmpty)
    }

    // MARK: Query Transfer

    @Test func findsTransferByTransferID() async throws {
        let (container, writer) = try await makeStore()
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: UUID(),
            amount: -50,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: UUID(),
            amount: 50,
            type: .transfer(transferID)
        )
        try await writer.save(fromLeg)
        try await writer.save(toLeg)

        let (foundFrom, foundTo) = try #require(try await reader(container).queryTransfer(id: transferID))
        #expect(foundFrom.id == fromLeg.id)
        #expect(foundTo.id == toLeg.id)
        #expect(foundFrom.type.transferID == transferID)
        #expect(foundTo.type.transferID == transferID)
    }

    @Test func hidesDeletedTransferLeg() async throws {
        let (container, writer) = try await makeStore()
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: UUID(),
            amount: -50,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: UUID(),
            amount: 50,
            type: .transfer(transferID)
        )
        try await writer.save(fromLeg)
        try await writer.save(toLeg)
        try await writer.delete(fromLeg.delete(at: Date()))

        #expect(try await reader(container).queryTransfer(id: transferID) == nil)
    }

    @Test func returnsNilWhenTransferNotFound() async throws {
        let (_, transactions) = try await makeStore()
        #expect(try await transactions.queryTransfer(id: UUID()) == nil)
    }

    // MARK: Query Counterpart

    @Test func findsCounterpartByTransactionID() async throws {
        let (container, writer) = try await makeStore()
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: UUID(),
            amount: -50,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: UUID(),
            amount: 50,
            type: .transfer(transferID)
        )
        try await writer.save(fromLeg)
        try await writer.save(toLeg)

        let counterpart = try #require(
            try await reader(container).queryCounterpart(transactionID: fromLeg.id)
        )
        #expect(counterpart.id == toLeg.id)
        let other = try #require(
            try await reader(container).queryCounterpart(transactionID: toLeg.id)
        )
        #expect(other.id == fromLeg.id)
    }

    @Test func returnsNilWhenTransactionHasNoTransfer() async throws {
        let (_, transactions) = try await makeStore()
        let transaction = try Transaction.make()
        try await transactions.save(transaction)

        #expect(try await transactions.queryCounterpart(transactionID: transaction.id) == nil)
    }

    @Test func returnsNilWhenCounterpartIsDeleted() async throws {
        let (container, writer) = try await makeStore()
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            amount: -50,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            amount: 50,
            type: .transfer(transferID)
        )
        try await writer.save(fromLeg)
        try await writer.save(toLeg)
        try await writer.delete(toLeg.delete(at: Date()))

        #expect(try await reader(container).queryCounterpart(transactionID: fromLeg.id) == nil)
    }

    @Test func returnsNilWhenTransactionIsDeleted() async throws {
        let (_, transactions) = try await makeStore()
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            amount: -50,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            amount: 50,
            type: .transfer(transferID)
        )
        try await transactions.save(fromLeg)
        try await transactions.save(toLeg)
        try await transactions.delete(fromLeg.delete(at: Date()))

        #expect(try await transactions.queryCounterpart(transactionID: fromLeg.id) == nil)
    }

    @Test func returnsNilWhenTransferLegIsAlone() async throws {
        let (_, transactions) = try await makeStore()
        let leg = try Transaction.make(
            amount: -50,
            type: .transfer(UUID())
        )
        try await transactions.save(leg)

        #expect(try await transactions.queryCounterpart(transactionID: leg.id) == nil)
    }

    @Test func returnsNilWhenTransactionIsMissing() async throws {
        let (_, transactions) = try await makeStore()
        #expect(try await transactions.queryCounterpart(transactionID: UUID()) == nil)
    }

    // MARK: Delete

    @Test func persistsADeletedTransaction() async throws {
        let (container, transactions) = try await makeStore()
        let transaction = try Transaction.make()
        try await transactions.save(transaction)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let deleted = transaction.delete(at: deletedAt)
        try await transactions.delete(deleted)

        #expect(try await storedDeletedAt(id: transaction.id, in: container) == deletedAt)
    }

    @Test func doesNotOverwriteDeletedAt() async throws {
        let (container, transactions) = try await makeStore()
        let transaction = try Transaction.make()
        try await transactions.save(transaction)
        let original = Date(timeIntervalSince1970: 1)
        try await transactions.delete(transaction.delete(at: original))
        try await transactions.delete(
            DeletedTransaction(id: transaction.id, deletedAt: Date(timeIntervalSince1970: 2))
        )

        #expect(try await storedDeletedAt(id: transaction.id, in: container) == original)
    }

    @Test func doesNothingWhenMissing() async throws {
        let (container, transactions) = try await makeStore()
        let id = UUID()
        try await transactions.delete(
            DeletedTransaction(id: id, deletedAt: Date(timeIntervalSince1970: 1_700_000_000))
        )

        #expect(try await storedDeletedAt(id: id, in: container) == nil)
    }

    // MARK: - Helpers

    private func makeStore() async throws -> (ModelContainer, DurableTransactionRepository) {
        let container = try await MainActor.run {
            try Persistence.makeContainer(inMemory: true)
        }
        return (container, DurableTransactionRepository(modelContainer: container))
    }

    private func reader(_ container: ModelContainer) -> DurableTransactionRepository {
        DurableTransactionRepository(modelContainer: container)
    }

    private func storedDeletedAt(id: UUID, in container: ModelContainer) async throws -> Date? {
        try await MainActor.run {
            let context = ModelContext(container)
            let transactionID = id
            var descriptor = FetchDescriptor<TransactionRecord>(
                predicate: #Predicate { $0.id == transactionID }
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.deletedAt
        }
    }
}
