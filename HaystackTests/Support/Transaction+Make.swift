import Foundation
@testable import Haystack

extension Transaction {
    static func make(
        id: UUID = UUID(),
        accountID: UUID = UUID(),
        date: (year: Int, month: Int, day: Int) = (year: 2026, month: 8, day: 31),
        amount: Decimal = 10,
        notes: String = ""
    ) throws -> Transaction {
        try Transaction(
            id: id,
            accountID: accountID,
            date: date,
            amount: amount,
            notes: notes
        )
    }
}
