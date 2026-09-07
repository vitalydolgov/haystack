import Foundation
@testable import Haystack

extension Account {
    static func make(
        id: UUID = UUID(),
        name: String = "Wallet",
        type: AccountType = .cash,
        notes: String = "",
        isClosed: Bool = false
    ) throws -> Account {
        try Account(
            id: id,
            name: name,
            type: type,
            notes: notes,
            isClosed: isClosed
        )
    }
}
