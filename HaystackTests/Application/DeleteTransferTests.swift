import Foundation
import Testing
@testable import Haystack

struct DeleteTransferTests {
    @Test func deletesBothLegs() async throws {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: UUID(),
            amount: -10,
            type: .transfer,
            transferID: transferID
        )
        let toLeg = try Transaction.make(
            accountID: UUID(),
            amount: 10,
            type: .transfer,
            transferID: transferID
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await DeleteTransfer(unitOfWork: unitOfWork).execute(id: transferID, at: deletedAt)
        #expect(await transactions.find(id: fromLeg.id) == nil)
        #expect(await transactions.find(id: toLeg.id) == nil)
    }

    // MARK: Errors

    @Test func failsWhenNotFound() async {
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(transactions: transactions)

        await #expect(throws: TransferError.notFound) {
            try await DeleteTransfer(unitOfWork: unitOfWork).execute(id: UUID())
        }
    }
}
