import Foundation

struct ReopenAccount {
    let unitOfWork: UnitOfWork

    func execute(id: UUID) async throws {
        try await unitOfWork.perform { store in
            guard var account = await store.accounts.find(id: id) else {
                throw AccountError.notFound
            }
            account.reopen()
            try await store.accounts.save(account)
        }
    }
}
