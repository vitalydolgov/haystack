import Foundation
import TransactionalMacro

struct ReplaceTransfer {
    let unitOfWork: UnitOfWork

    static func canExecute(fromAccountID: UUID, toAccountID: UUID, amount: Decimal) -> Bool {
        fromAccountID != toAccountID && amount > 0
    }

    // TODO: refactor with apply method
    @Transactional
    func execute(
        id: UUID,
        fromAccountID: UUID,
        toAccountID: UUID,
        date: Date,
        amount: Decimal,
        notes: String = ""
    ) async throws {
        // TODO: guard with canExecute
        // TODO: check invariants before saving
        guard amount > 0 else { throw TransferError.invalidAmount }
        try await DeleteTransfer(unitOfWork: unitOfWork).execute(id: id)
        _ = try await AddTransfer(unitOfWork: unitOfWork).execute(
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            date: date,
            magnitude: amount,
            notes: notes
        )
    }
}
