import Foundation
import TransactionalMacro

struct EditAccount {
    let unitOfWork: UnitOfWork

    static func canExecute(name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @Transactional
    func execute(id: UUID, name: String, notes: String, workingBalance: Decimal) async throws {
        guard var account = await store.accounts.find(id: id) else {
            throw AccountError.notFound
        }
        if !account.isClosed {
            try await AdjustBalance(unitOfWork: unitOfWork).execute(id: id, to: workingBalance)
        }
        try account.rename(name)
        account.notes = notes
        try await store.accounts.save(account)
    }
}
