import Foundation

struct CloseAccount {
    private let accounts: AccountRepository
    private let transactions: TransactionRepository

    init(accounts: AccountRepository, transactions: TransactionRepository) {
        self.accounts = accounts
        self.transactions = transactions
    }

    func execute(id: UUID) async throws {
        guard var account = await accounts.find(id: id) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { return }
        let adjustBalance = AdjustBalance(accounts: accounts, transactions: transactions)
        try await adjustBalance.execute(id: id, to: 0)
        try account.close(await transactions.find(accountID: id))
        try await accounts.save(account)
    }
}
