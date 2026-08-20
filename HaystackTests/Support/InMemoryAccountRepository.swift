import Foundation
@testable import Haystack

actor InMemoryAccountRepository: AccountRepository {
    private var accounts: [UUID: Account] = [:]
    private var tombstones: [UUID: DeletedAccount] = [:]

    func save(_ account: Account) {
        guard tombstones[account.id] == nil else { return }
        accounts[account.id] = account
    }

    func find(id: UUID) -> Account? {
        accounts[id]
    }

    func delete(_ account: DeletedAccount) {
        guard tombstones[account.id] == nil else { return }
        accounts[account.id] = nil
        tombstones[account.id] = account
    }

    func deleted(id: UUID) -> DeletedAccount? {
        tombstones[id]
    }

    func all() -> [Account] {
        Array(accounts.values)
    }
}
