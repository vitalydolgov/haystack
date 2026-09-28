import Foundation
import TransactionalMacro

struct AddAccount {
    let unitOfWork: UnitOfWork

    static func canExecute(name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    @Transactional
    func execute(
        name: String,
        type: AccountType,
        notes: String = "",
        balance: Decimal = 0
    ) async throws -> Account {
        let account = try Account(name: name, type: type, notes: notes)
        try await store.accounts.save(account)
        if balance != 0 {
            let transaction = try Transaction(
                accountID: account.id,
                date: Date.now.asYearMonthDay(),
                amount: balance,
                type: .adjustment
            )
            try await store.transactions.save(transaction)
        }
        return account
    }
}
