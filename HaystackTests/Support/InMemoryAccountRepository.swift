import Foundation
@testable import Haystack

actor InMemoryAccountRepository: AccountRepository {
    private var accounts: [UUID: Account] = [:]
    private var tombstones: [UUID: DeletedAccount] = [:]

    func save(_ account: Account) {
        guard tombstones[account.id] == nil else { return }
        accounts[account.id] = account
    }

    func save(batch: [Account]) {
        for account in batch {
            save(account)
        }
    }

    func query(id: UUID, includeDeleted _: Bool) -> Account? {
        accounts[id]
    }

    func query(_ query: AccountQuery) -> [Account] {
        switch query {
        case .open:
            accounts.values.filter { !$0.isClosed }.sorted { $0.name < $1.name }
        case .includingClosed:
            accounts.values.sorted { $0.name < $1.name }
        }
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

    func snapshot() -> ([UUID: Account], [UUID: DeletedAccount]) {
        (accounts, tombstones)
    }

    func restore(_ snapshot: ([UUID: Account], [UUID: DeletedAccount])) {
        (accounts, tombstones) = snapshot
    }
}
