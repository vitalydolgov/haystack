import Foundation

struct CloseAccount {
    private let accounts: AccountRepository

    init(accounts: AccountRepository) {
        self.accounts = accounts
    }

    func execute(id: UUID) async throws {
        guard let existing = await accounts.find(id: id) else {
            throw AccountError.notFound
        }
        guard !existing.isClosed else { return }
        var account = try await AdjustBalance(accounts: accounts).stage(id: id, to: 0)
        try account.close()
        try await accounts.save(account)
    }
}
