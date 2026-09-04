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
            notes: "Groceries"
        )
        try await writer.save(transaction)

        let stored = try #require(await reader(container).find(id: transaction.id))
        #expect(stored.id == transaction.id)
        #expect(stored.accountID == accountID)
        #expect(stored.date == (year: 2024, month: 3, day: 15))
        #expect(stored.amount == -42.5)
        #expect(stored.notes == "Groceries")
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

        let stored = try #require(await reader(container).find(id: transaction.id))
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

        #expect(await transactions.find(id: rent.id)?.notes == "Rent")
        #expect(await transactions.find(id: pay.id)?.notes == "Pay")
    }

    @Test func doesNotResurrectADeletedTransaction() async throws {
        let (_, transactions) = try await makeStore()
        let transaction = try Transaction.make()
        try await transactions.save(transaction)
        let deleted = transaction.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        try await transactions.delete(deleted)
        try await transactions.save(transaction)

        #expect(await transactions.find(id: transaction.id) == nil)
    }

    // MARK: Find

    @Test func findsALiveTransaction() async throws {
        let (container, writer) = try await makeStore()
        let transaction = try Transaction.make()
        try await writer.save(transaction)

        #expect(await reader(container).find(id: transaction.id) != nil)
    }

    @Test func hidesADeletedTransaction() async throws {
        let (_, transactions) = try await makeStore()
        let transaction = try Transaction.make()
        try await transactions.save(transaction)
        let deleted = transaction.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        try await transactions.delete(deleted)

        #expect(await transactions.find(id: transaction.id) == nil)
    }

    @Test func returnsNilWhenMissing() async throws {
        let (_, transactions) = try await makeStore()
        #expect(await transactions.find(id: UUID()) == nil)
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

    private func makeStore() async throws -> (ModelContainer, SwiftDataTransactionRepository) {
        let container = try await MainActor.run {
            try Persistence.makeContainer(inMemory: true)
        }
        return (container, SwiftDataTransactionRepository(modelContainer: container))
    }

    private func reader(_ container: ModelContainer) -> SwiftDataTransactionRepository {
        SwiftDataTransactionRepository(modelContainer: container)
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
