import Foundation
@testable import Haystack

extension Account {
    func balance(_ transactions: [Transaction]) -> Decimal {
        transactions.reduce(into: 0) { total, transaction in
            guard transaction.accountID == id else { return }
            total += transaction.amount
        }
    }
}
