import Foundation
@testable import Haystack

actor InMemoryAccountRepository: AccountRepository {
    private var storage: [UUID: Account] = [:]

    func save(_ account: Account) {
        storage[account.id] = account
    }

    func find(id: UUID) -> Account? {
        storage[id]
    }

    func delete(_ account: Account) {
        storage[account.id] = nil
    }

    func all() -> [Account] {
        Array(storage.values)
    }
}
