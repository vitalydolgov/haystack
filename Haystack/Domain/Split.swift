import Foundation

enum Split {
    static func validate(total: Transaction, parts: [Transaction]) throws {
        guard case .split(let splitID) = total.type, splitID == total.id else {
            throw SplitError.malformed
        }
        guard Set(parts.map(\.id)).count == parts.count else {
            throw SplitError.malformed
        }
        for part in parts {
            guard part.id != total.id else { throw SplitError.malformed }
            switch part.type {
            case .splitPart(let partSplitID, .standard),
                 .splitPart(let partSplitID, .transfer):
                guard partSplitID == splitID, part.accountID == total.accountID else {
                    throw SplitError.malformed
                }
            case .standard, .transfer, .split, .splitPart:
                throw SplitError.malformed
            }
        }
        let transferIDs = parts.compactMap(\.type.transferID)
        guard Set(transferIDs).count == transferIDs.count else {
            throw SplitError.malformed
        }
        guard parts.reduce(Decimal(0), { $0 + $1.amount }) == total.amount else {
            throw SplitError.invalidAmount
        }
    }
}
