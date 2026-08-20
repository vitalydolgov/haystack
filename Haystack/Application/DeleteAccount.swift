import Foundation

struct DeleteAccount {
    private let accounts: AccountRepository

    init(accounts: AccountRepository) {
        self.accounts = accounts
    }

    func execute(id: UUID) async throws {
        guard let account = await accounts.find(id: id) else {
            throw AccountError.notFound
        }
        try account.delete()
        try await accounts.delete(account)
    }
}
