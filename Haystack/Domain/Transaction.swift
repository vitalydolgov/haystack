import Foundation

enum TransactionType: String, Codable, Sendable, Equatable, CaseIterable {
    case standard
    case adjustment
    case transfer
}

enum TransferError: Error, Equatable, Sendable {
    case sameAccount
    case notFound
}

enum TransactionError: Error, Equatable, Sendable {
    case invalidDate
    case notFound
}

struct Transaction: Identifiable, Equatable, Sendable {
    let id: UUID
    let accountID: UUID
    let type: TransactionType
    let transferID: UUID?
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
        transferID: UUID? = nil
    ) throws {
        self.id = id
        self.accountID = accountID
        self.date = try Self.validatedDate(date)
        self.amount = amount
        self.notes = notes
        self.type = type
        self.transferID = transferID
    }

    mutating func update(
        date: (year: Int, month: Int, day: Int),
        amount: Decimal,
        notes: String
    ) throws {
        self.date = try Self.validatedDate(date)
        self.amount = amount
        self.notes = notes
    }

    func delete(at date: Date = .now) -> DeletedTransaction {
        DeletedTransaction(id: id, deletedAt: date)
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
