import Foundation

extension Split {
    static func validate(draft transaction: Transaction, parts: [Transaction]) throws {
        guard transaction.type == .standard else {
            throw SplitError.malformed
        }
        guard parts.count == Set(parts.map(\.id)).count, parts.count >= 2 else {
            throw SplitError.malformed
        }
        for part in parts {
            switch part.type {
            case .standard:
                guard part.accountID == transaction.accountID else { throw SplitError.malformed }
            case .transfer:
                guard part.accountID != transaction.accountID else { throw SplitError.malformed }
            case .split, .splitPart:
                throw SplitError.malformed
            }
        }
        guard parts.reduce(Decimal(0), { $0 + $1.amount }) == transaction.amount else {
            throw SplitError.invalidAmount
        }
    }
}
