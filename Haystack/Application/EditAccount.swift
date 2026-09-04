import Foundation

struct EditAccount {
    private let accounts: AccountRepository
    private let transactions: TransactionRepository

    init(accounts: AccountRepository, transactions: TransactionRepository) {
        self.accounts = accounts
        self.transactions = transactions
    }

    static func canExecute(name: String, workingBalance: Decimal?, closed: Bool) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        return closed || workingBalance != nil
    }

    func execute(id: UUID, name: String, notes: String, workingBalance: Decimal?) async throws {
        guard var account = await accounts.find(id: id) else {
            throw AccountError.notFound
        }
        var adjustment: Transaction?
        if !account.isClosed, let workingBalance {
            let current = account.balance(await transactions.find(accountID: id))
            if current != workingBalance {
                let adjustBalance = AdjustBalance(accounts: accounts, transactions: transactions)
                adjustment = try await adjustBalance.stage(id: id, to: workingBalance)
            }
        }
        try account.rename(name)
        account.notes = notes
        if let adjustment {
            try await transactions.save(adjustment)
        }
        try await accounts.save(account)
    }
}
