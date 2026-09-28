import Foundation
import TransactionalMacro

struct ReplaceTransfer {
    let unitOfWork: UnitOfWork

    @Transactional
    func execute(
        id: UUID,
        fromAccountID: UUID,
        toAccountID: UUID,
        date: Date,
        amount: Decimal,
        notes: String = ""
    ) async throws {
        guard amount > 0 else { throw TransferError.invalidAmount }
        try await DeleteTransfer(unitOfWork: unitOfWork).execute(id: id)
        _ = try await AddTransfer(unitOfWork: unitOfWork).execute(
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            date: date,
            amount: amount,
            notes: notes
        )
    }
}
