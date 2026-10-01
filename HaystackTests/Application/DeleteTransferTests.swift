import Foundation
import Testing
@testable import Haystack

struct DeleteTransferTests {
    @Test func deletesBothLegs() async throws {
        let accounts = InMemoryAccountRepository()
        let transactions = InMemoryTransactionRepository()
        let unitOfWork = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
        let fromAccount = try Account.make()
        let toAccount = try Account.make()
        await accounts.save(fromAccount)
        await accounts.save(toAccount)
        let transferID = UUID()
        let fromLeg = try Transaction.make(
            accountID: fromAccount.id,
            amount: -10,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction.make(
            accountID: toAccount.id,
            amount: 10,
            type: .transfer(transferID)
        )
        await transactions.save(fromLeg)
        await transactions.save(toLeg)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await DeleteTransfer(unitOfWork: unitOfWork).execute(id: transferID, at: deletedAt)
        #expect(await transactions.query(id: fromLeg.id) == nil)
        #expect(await transactions.query(id: toLeg.id) == nil)
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
