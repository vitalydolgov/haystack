import Foundation

struct EditAccount {
    private let accounts: AccountRepository

    init(accounts: AccountRepository) {
        self.accounts = accounts
    }

    static func canExecute(name: String, workingBalance: Decimal?, isClosed: Bool) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        return isClosed || workingBalance != nil
    }

    func execute(id: UUID, name: String, notes: String, workingBalance: Decimal?) async throws {
        guard var account = await accounts.find(id: id) else {
            throw AccountError.notFound
        }
        if !account.isClosed, let workingBalance, account.balance != workingBalance {
            account = try await AdjustBalance(accounts: accounts).stage(id: id, to: workingBalance)
        }
        try account.rename(name)
        account.notes = notes
        try await accounts.save(account)
    }
}
