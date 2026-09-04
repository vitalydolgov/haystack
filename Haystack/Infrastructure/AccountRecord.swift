import Foundation
import SwiftData

@Model
final class AccountRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: AccountType
    var notes: String
    var isClosed: Bool
    var deletedAt: Date?

    init(
        id: UUID,
        name: String,
        type: AccountType,
        notes: String,
        isClosed: Bool,
        deletedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.notes = notes
        self.isClosed = isClosed
        self.deletedAt = deletedAt
    }

    convenience init(_ account: Account) {
        self.init(
            id: account.id,
            name: account.name,
            type: account.type,
            notes: account.notes,
            isClosed: account.isClosed,
            deletedAt: nil
        )
    }

    func toAccount() throws -> Account {
        try Account(
            id: id,
            name: name,
            type: type,
            notes: notes,
            isClosed: isClosed
        )
    }

    func update(from account: Account) {
        name = account.name
        type = account.type
        notes = account.notes
        isClosed = account.isClosed
    }
}
