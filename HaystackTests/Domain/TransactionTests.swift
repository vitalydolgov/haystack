import Foundation
import Testing
@testable import Haystack

struct TransactionTests {
    // MARK: Identity

    @Test func sameIDMeansEqual() throws {
        let id = UUID()
        let left = try Transaction.make(id: id, amount: 10)
        let right = try Transaction.make(
            id: id,
            accountID: UUID(),
            date: (year: 2024, month: 1, day: 1),
            amount: -5,
            notes: "changed",
            type: .adjustment
        )

        #expect(left == right)
    }

    @Test func differentIDsAreNotEqual() throws {
        let left = try Transaction.make()
        let right = try Transaction.make()

        #expect(left != right)
    }

    // MARK: Type

    @Test func startsAsStandard() throws {
        let transaction = try Transaction.make()
        #expect(transaction.type == .standard)
    }

    // MARK: Date

    @Test func acceptsARealGregorianDay() throws {
        let transaction = try Transaction.make(date: (year: 2024, month: 2, day: 29))
        #expect(transaction.date == (year: 2024, month: 2, day: 29))
    }

    @Test(arguments: [
        (year: 2026, month: 2, day: 30),
        (year: 2025, month: 2, day: 29),
        (year: 2026, month: 13, day: 1),
        (year: 2026, month: 0, day: 1),
        (year: 2026, month: 1, day: 0),
        (year: 2026, month: 1, day: 32),
    ])
    func rejectsAnInvalidGregorianDay(date: (year: Int, month: Int, day: Int)) {
        #expect(throws: TransactionError.invalidDate) {
            try Transaction.make(date: date)
        }
    }

    // MARK: Update

    @Test func updatesDateAmountAndNotes() throws {
        var transaction = try Transaction.make()
        try transaction.update(
            date: (year: 2024, month: 12, day: 25),
            amount: -12.5,
            notes: "Gift"
        )

        #expect(transaction.date == (year: 2024, month: 12, day: 25))
        #expect(transaction.amount == -12.5)
        #expect(transaction.notes == "Gift")
    }

    @Test func failsWhenTheNewDateIsInvalid() throws {
        var transaction = try Transaction.make(
            date: (year: 2026, month: 8, day: 31),
            amount: 10,
            notes: "Keep"
        )

        #expect(throws: TransactionError.invalidDate) {
            try transaction.update(
                date: (year: 2026, month: 2, day: 30),
                amount: 99,
                notes: "Changed"
            )
        }
        #expect(transaction.date == (year: 2026, month: 8, day: 31))
        #expect(transaction.amount == 10)
        #expect(transaction.notes == "Keep")
    }

    // MARK: Delete

    @Test func recordsDeletedAt() throws {
        let transaction = try Transaction.make()
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let deleted = transaction.delete(at: deletedAt)
        #expect(deleted.id == transaction.id)
        #expect(deleted.deletedAt == deletedAt)
    }
}
