import Foundation

struct ReopenAccount {
    private let accounts: AccountRepository

    init(accounts: AccountRepository) {
        self.accounts = accounts
    }

    func execute(id: UUID) async throws {
        guard var account = await accounts.find(id: id) else {
            throw AccountError.notFound
        }
        account.reopen()
        try await accounts.save(account)
    }
}
