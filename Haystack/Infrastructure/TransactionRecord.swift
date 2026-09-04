import Foundation
import SwiftData

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var type: TransactionType
    var year: Int
    var month: Int
    var day: Int
    var amount: Decimal
    var notes: String
    var deletedAt: Date?

    init(
        id: UUID,
        accountID: UUID,
        type: TransactionType,
        year: Int,
        month: Int,
        day: Int,
        amount: Decimal,
        notes: String,
        deletedAt: Date?
    ) {
        self.id = id
        self.accountID = accountID
        self.type = type
        self.year = year
        self.month = month
        self.day = day
        self.amount = amount
        self.notes = notes
        self.deletedAt = deletedAt
    }

    convenience init(_ transaction: Transaction) {
        self.init(
            id: transaction.id,
            accountID: transaction.accountID,
            type: transaction.type,
            year: transaction.date.year,
            month: transaction.date.month,
            day: transaction.date.day,
            amount: transaction.amount,
            notes: transaction.notes,
            deletedAt: nil
        )
    }

    func toTransaction() throws -> Transaction {
        try Transaction(
            id: id,
            accountID: accountID,
            date: (year: year, month: month, day: day),
            amount: amount,
            notes: notes,
            type: type
        )
    }

    func update(from transaction: Transaction) {
        year = transaction.date.year
        month = transaction.date.month
        day = transaction.date.day
        amount = transaction.amount
        notes = transaction.notes
    }
}
