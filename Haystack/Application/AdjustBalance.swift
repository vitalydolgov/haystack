import Foundation

struct AdjustBalance {
    private let accounts: AccountRepository

    init(accounts: AccountRepository) {
        self.accounts = accounts
    }

    func stage(id: UUID, to balance: Decimal) async throws -> Account {
        guard var account = await accounts.find(id: id) else {
            throw AccountError.notFound
        }
        try account.adjustBalance(to: balance)
        return account
    }

    func execute(id: UUID, to balance: Decimal) async throws {
        let account = try await stage(id: id, to: balance)
        try await accounts.save(account)
    }
}
