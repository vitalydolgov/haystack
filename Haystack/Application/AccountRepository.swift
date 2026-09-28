import Foundation

enum AccountQuery: Sendable {
    case open
    case includingClosed
}

protocol AccountQuerying: Sendable {
    func query(id: UUID, includeDeleted: Bool) async throws -> Account?
    func query(_ query: AccountQuery) async throws -> [Account]
}

extension AccountQuerying {
    func query(id: UUID) async throws -> Account? {
        try await self.query(id: id, includeDeleted: false)
    }
}

protocol AccountRepository: AccountQuerying, Sendable {
    func save(_ account: Account) async throws
    func delete(_ account: DeletedAccount) async throws
}
