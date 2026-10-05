import Foundation

enum TransactionType: Codable, Sendable, Equatable {
    case standard
    case transfer(UUID)
    case split(UUID)
    indirect case splitPart(UUID, TransactionType)

    var transferID: UUID? {
        switch self {
        case .transfer(let id):
            id
        case .splitPart(_, let type):
            type.transferID
        default:
            nil
        }
    }

    var splitID: UUID? {
        switch self {
        case .split(let id), .splitPart(let id, _):
            id
        default:
            nil
        }
    }
}

enum TransferError: Error, Equatable, Sendable {
    case invalidAmount
    case sameAccount
    case notFound
}

enum TransactionError: Error, Equatable, Sendable {
    case invalidAmount
    case invalidDate
    case notFound
}

enum SplitError: Error, Equatable, Sendable {
    case malformed
    case invalidAmount
}

struct Transaction: Identifiable, Equatable, Sendable {
    let id: UUID
    let accountID: UUID
    private(set) var type: TransactionType
    private(set) var date: (year: Int, month: Int, day: Int)
    private(set) var amount: Decimal
    private(set) var notes: String

    init(
        id: UUID = UUID(),
        accountID: UUID,
        date: (year: Int, month: Int, day: Int),
        amount: Decimal,
        notes: String = "",
        type: TransactionType = .standard,
    ) throws {
        self.id = id
        self.accountID = accountID
        self.date = try Self.validatedDate(date)
        self.amount = try Self.validatedAmount(amount)
        self.notes = notes
        self.type = type
    }

    mutating func update(
        date: (year: Int, month: Int, day: Int),
        amount: Decimal,
        notes: String
    ) throws {
        let date = try Self.validatedDate(date)
        let amount = try Self.validatedAmount(amount)
        self.date = date
        self.amount = amount
        self.notes = notes
    }

    mutating func wrap(in split: UUID) {
        type = .splitPart(split, type)
    }

    func delete(at date: Date = .now) -> DeletedTransaction {
        DeletedTransaction(id: id, deletedAt: date)
    }

    private static func validatedAmount(_ amount: Decimal) throws -> Decimal {
        guard amount != 0 else { throw TransactionError.invalidAmount }
        return amount
    }

    private static func validatedDate(
        _ date: (year: Int, month: Int, day: Int)
    ) throws -> (year: Int, month: Int, day: Int) {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = date.year
        components.month = date.month
        components.day = date.day
        guard components.isValidDate else { throw TransactionError.invalidDate }
        return date
    }

    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.id == rhs.id
    }

    static func date(from components: (year: Int, month: Int, day: Int)) -> Date {
        var c = DateComponents()
        c.calendar = Calendar(identifier: .gregorian)
        c.year = components.year
        c.month = components.month
        c.day = components.day
        return c.date!
    }
}

struct DeletedTransaction: Identifiable, Equatable, Sendable {
    let id: UUID
    let deletedAt: Date
}

extension Date {
    func asYearMonthDay() -> (year: Int, month: Int, day: Int) {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: self)
        return (components.year!, components.month!, components.day!)
    }
}
