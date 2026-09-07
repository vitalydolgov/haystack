import Foundation

struct AddAccount {
    private let unitOfWork: UnitOfWork

    init(unitOfWork: UnitOfWork) {
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
    ) async throws -> Account {
        try await unitOfWork.perform {
            let account = try Account(name: name, type: type, notes: notes)
            try await unitOfWork.accounts.save(account)
            if balance != 0 {
                try await unitOfWork.transactions.save(
                    Transaction(accountID: account.id, date: date, amount: balance, type: .adjustment)
                )
            }
            return account
        }
    }
}
