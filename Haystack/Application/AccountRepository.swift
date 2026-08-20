import Foundation

protocol AccountRepository: Sendable {
    func save(_ account: Account) async throws
    func find(id: UUID) async -> Account?
    func delete(_ account: Account) async throws
}
