import Foundation

struct AdjustBalance {
    let unitOfWork: UnitOfWork

    func execute(id: UUID, to balance: Decimal, on date: Date = .now) async throws {
        try await unitOfWork.perform { store in
            guard let account = await store.accounts.find(id: id) else {
                throw AccountError.notFound
            }
            guard !account.isClosed else { throw AccountError.closed }
            let existing = await store.transactions.find(accountID: id)
            let delta = balance - account.balance(existing)
            guard delta != 0 else { return }
            let transaction = try Transaction(
                accountID: id,
                date: date,
                amount: delta,
                type: .adjustment
            )
            try await store.transactions.save(transaction)
        }
    }
}
