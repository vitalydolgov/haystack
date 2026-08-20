import Foundation

struct DeleteAccount {
    // TODO: purge accounts whose deletedAt is older than the retention window
    private let accounts: AccountRepository

    init(accounts: AccountRepository) {
        self.accounts = accounts
    }

    func execute(id: UUID, at date: Date = .now) async throws {
        guard let account = await accounts.find(id: id) else {
            throw AccountError.notFound
        }
        let deleted = try account.delete(at: date)
        try await accounts.delete(deleted)
    }
}
