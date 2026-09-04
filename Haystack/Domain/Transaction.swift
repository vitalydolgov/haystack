import Foundation

enum TransactionError: Error, Equatable, Sendable {
    case invalidDate
}

struct Transaction: Identifiable, Equatable, Sendable {
    let id: UUID
    let accountID: UUID
    private(set) var date: (year: Int, month: Int, day: Int)
    private(set) var amount: Decimal
    private(set) var notes: String

    init(
        id: UUID = UUID(),
        accountID: UUID,
        date: (year: Int, month: Int, day: Int),
        amount: Decimal,
        notes: String = ""
    ) throws {
        self.id = id
        self.accountID = accountID
        self.date = try Self.validatedDate(date)
        self.amount = amount
        self.notes = notes
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
}

struct DeletedTransaction: Identifiable, Equatable, Sendable {
    let id: UUID
    let deletedAt: Date
}
