import Foundation

struct AddAccount {
    private let accounts: AccountRepository
    private let transactions: TransactionRepository
    private let unitOfWork: UnitOfWork

    init(accounts: AccountRepository, transactions: TransactionRepository, unitOfWork: UnitOfWork) {
        self.accounts = accounts
        self.transactions = transactions
        self.unitOfWork = unitOfWork
    }

    static func canExecute(name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func execute(
        name: String,
        type: AccountType,
        notes: String = "",
        balance: Decimal = 0,
        on date: Date = .now
    ) async throws {
        do {
            let account = try Account(name: name, type: type, notes: notes)
            try await accounts.save(account)
            if balance != 0 {
                try await transactions.save(
                    Transaction(accountID: account.id, date: date, amount: balance, type: .adjustment)
                )
            }
            try await unitOfWork.commit()
        } catch {
            await unitOfWork.rollback()
            throw error
        }
    }
}
