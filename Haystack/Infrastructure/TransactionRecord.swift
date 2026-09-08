import Foundation
import SwiftData

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var type: TransactionType
    var packedDate: Int
    var amount: Decimal
    var notes: String
    var transferID: UUID?
    var deletedAt: Date?

    init(
        id: UUID,
        accountID: UUID,
        type: TransactionType,
        packedDate: Int,
        amount: Decimal,
        notes: String,
        transferID: UUID? = nil,
        deletedAt: Date?
    ) {
        self.id = id
        self.accountID = accountID
        self.type = type
        self.packedDate = packedDate
        self.amount = amount
        self.notes = notes
        self.transferID = transferID
        self.deletedAt = deletedAt
    }

    convenience init(_ transaction: Transaction) {
        self.init(
            id: transaction.id,
            accountID: transaction.accountID,
            type: transaction.type,
            packedDate: Self.packedDate(from: transaction.date),
            amount: transaction.amount,
            notes: transaction.notes,
            transferID: transaction.transferID,
            deletedAt: nil
        )
    }

    func toTransaction() throws -> Transaction {
        try Transaction(
            id: id,
            accountID: accountID,
            date: unpackedDate,
            amount: amount,
            notes: notes,
            type: type,
            transferID: transferID
        )
    }

    func update(from transaction: Transaction) {
        accountID = transaction.accountID
        type = transaction.type
        packedDate = Self.packedDate(from: transaction.date)
        amount = transaction.amount
        notes = transaction.notes
        transferID = transaction.transferID
    }

    var unpackedDate: (year: Int, month: Int, day: Int) {
        (year: packedDate / 10_000, month: (packedDate / 100) % 100, day: packedDate % 100)
    }

    static func packedDate(from date: (year: Int, month: Int, day: Int)) -> Int {
        date.year * 10_000 + date.month * 100 + date.day
    }
}
