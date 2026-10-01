import Foundation
import SwiftData

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var type: RecordTransactionType
    var packedDate: Int
    var amount: Decimal
    var notes: String
    var transferID: UUID?
    var splitID: UUID?
    var deletedAt: Date?

    init(
        id: UUID,
        accountID: UUID,
        type: RecordTransactionType,
        packedDate: Int,
        amount: Decimal,
        notes: String,
        transferID: UUID? = nil,
        splitID: UUID? = nil,
        deletedAt: Date?
    ) {
        self.id = id
        self.accountID = accountID
        self.type = type
        self.packedDate = packedDate
        self.amount = amount
        self.notes = notes
        self.transferID = transferID
        self.splitID = splitID
        self.deletedAt = deletedAt
    }

    convenience init(_ transaction: Transaction) {
        self.init(
            id: transaction.id,
            accountID: transaction.accountID,
            type: RecordTransactionType(from: transaction.type),
            packedDate: Self.packedDate(from: transaction.date),
            amount: transaction.amount,
            notes: transaction.notes,
            transferID: transaction.type.transferID,
            splitID: transaction.type.splitID,
            deletedAt: nil
        )
    }

    private enum RecordError: Error {
        case unreadableType
    }

    private var transactionType: TransactionType {
        get throws {
            switch type {
            case .standard:
                return .standard
            case .transfer:
                guard let transferID else { throw RecordError.unreadableType }
                return .transfer(transferID)
            case .split:
                guard let splitID else { throw RecordError.unreadableType }
                return .split(splitID)
            case .splitPart:
                guard let splitID else { throw RecordError.unreadableType }
                return if let transferID {
                    .splitPart(splitID, .transfer(transferID))
                } else {
                    .splitPart(splitID, .standard)
                }
            }
        }
    }

    func toTransaction() throws -> Transaction {
        try Transaction(
            id: id,
            accountID: accountID,
            date: unpackedDate,
            amount: amount,
            notes: notes,
            type: try transactionType
        )
    }

    func update(from transaction: Transaction) {
        accountID = transaction.accountID
        type = RecordTransactionType(from: transaction.type)
        packedDate = Self.packedDate(from: transaction.date)
        amount = transaction.amount
        notes = transaction.notes
        transferID = transaction.type.transferID
        splitID = transaction.type.splitID
    }

    var unpackedDate: (year: Int, month: Int, day: Int) {
        (year: packedDate / 10_000, month: (packedDate / 100) % 100, day: packedDate % 100)
    }

    static func packedDate(from date: (year: Int, month: Int, day: Int)) -> Int {
        date.year * 10_000 + date.month * 100 + date.day
    }
}

enum RecordTransactionType: String, Codable, Sendable, Equatable {
    case standard
    case transfer
    case split
    case splitPart

    init(from type: TransactionType) {
        self = switch type {
        case .standard: .standard
        case .transfer: .transfer
        case .split: .split
        case .splitPart: .splitPart
        }
    }
}
