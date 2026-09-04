import Foundation

enum AccountType: String, Codable, Sendable, Equatable, CaseIterable {
    case cash
    case debitCard
    case savings
}

enum AccountError: Error, Equatable, Sendable {
    case nonZeroBalance
    case blankName
    case closed
    case open
    case notFound
}

struct Account: Identifiable, Equatable, Sendable {
    let id: UUID
    private(set) var name: String
    var type: AccountType
    var notes: String
    private(set) var isClosed: Bool

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        notes: String = "",
        isClosed: Bool = false
    ) throws {
        self.id = id
        self.name = try Self.normalizedName(name)
        self.type = type
        self.notes = notes
        self.isClosed = isClosed
    }

    mutating func rename(_ name: String) throws {
        self.name = try Self.normalizedName(name)
    }

    mutating func close(_ transactions: [Transaction] = []) throws {
        guard !isClosed else { return }
        guard balance(transactions) == 0 else { throw AccountError.nonZeroBalance }
        isClosed = true
    }

    mutating func reopen() {
        isClosed = false
    }

    func balance(_ transactions: [Transaction]) -> Decimal {
        transactions.reduce(into: 0) { total, transaction in
            guard transaction.accountID == id else { return }
            total += transaction.amount
        }
    }

    func delete(at date: Date = .now) throws -> DeletedAccount {
        guard isClosed else { throw AccountError.open }
        return DeletedAccount(id: id, deletedAt: date)
    }

    private static func normalizedName(_ name: String) throws -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AccountError.blankName }
        return name
    }

    static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.id == rhs.id
    }
}

struct DeletedAccount: Identifiable, Equatable, Sendable {
    let id: UUID
    let deletedAt: Date
}
