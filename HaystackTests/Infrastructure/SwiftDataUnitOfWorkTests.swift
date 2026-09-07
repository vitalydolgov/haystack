import Foundation
import SwiftData
import Testing
@testable import Haystack

struct SwiftDataUnitOfWorkTests {
    private struct Boom: Error {}

    // MARK: Perform

    @Test func commitsOnSuccess() async throws {
        let (container, unitOfWork) = try await makeUnitOfWork()
        let account = try Account.make(name: "Wallet")

        try await unitOfWork.perform { store in
            try await store.accounts.save(account)
        }

        #expect(try await storedAccountCount(in: container) == 1)
    }

    @Test func returnsTheResultOfTheWork() async throws {
        let (_, unitOfWork) = try await makeUnitOfWork()

        let result = try await unitOfWork.perform { _ in 42 }

        #expect(result == 42)
    }

    @Test func rollsBackOnFailure() async throws {
        let (container, unitOfWork) = try await makeUnitOfWork()
        let account = try Account.make(name: "Wallet")

        await #expect(throws: Boom.self) {
            try await unitOfWork.perform { store in
                try await store.accounts.save(account)
                throw Boom()
            }
        }

        #expect(try await storedAccountCount(in: container) == 0)
    }

    @Test func doesNotCommitDiscardedWorkInALaterTransaction() async throws {
        let (container, unitOfWork) = try await makeUnitOfWork()
        let discarded = try Account.make(name: "Wallet")
        await #expect(throws: Boom.self) {
            try await unitOfWork.perform { store in
                try await store.accounts.save(discarded)
                throw Boom()
            }
        }

        try await unitOfWork.perform { store in
            try await store.accounts.save(try Account.make(name: "Checking"))
        }

        #expect(try await storedAccountCount(in: container) == 1)
    }

    @Test func doesNotRollBackAnEarlierTransaction() async throws {
        let (container, unitOfWork) = try await makeUnitOfWork()
        let account = try Account.make(name: "Wallet")
        try await unitOfWork.perform { store in
            try await store.accounts.save(account)
        }

        await #expect(throws: Boom.self) {
            try await unitOfWork.perform { store in
                try await store.accounts.save(try Account.make(name: "Checking"))
                throw Boom()
            }
        }

        #expect(try await storedAccountCount(in: container) == 1)
    }

    // MARK: Nesting

    @Test func commitsNestedWorkWithTheOuterTransaction() async throws {
        let (container, unitOfWork) = try await makeUnitOfWork()
        let account = try Account.make(name: "Wallet")
        let transaction = try Transaction.make(accountID: account.id, amount: 25)

        try await unitOfWork.perform { store in
            try await store.accounts.save(account)
            try await unitOfWork.perform { nested in
                try await nested.transactions.save(transaction)
            }
        }

        #expect(try await storedAccountCount(in: container) == 1)
        #expect(try await storedTransactionCount(in: container) == 1)
    }

    @Test func rollsBackNestedWorkWhenTheOuterTransactionFails() async throws {
        let (container, unitOfWork) = try await makeUnitOfWork()
        let account = try Account.make(name: "Wallet")
        let transaction = try Transaction.make(accountID: account.id, amount: 25)

        await #expect(throws: Boom.self) {
            try await unitOfWork.perform { store in
                try await store.accounts.save(account)
                try await unitOfWork.perform { nested in
                    try await nested.transactions.save(transaction)
                }
                throw Boom()
            }
        }

        #expect(try await storedAccountCount(in: container) == 0)
        #expect(try await storedTransactionCount(in: container) == 0)
    }

    // MARK: - Helpers

    private func makeUnitOfWork() async throws -> (ModelContainer, SwiftDataUnitOfWork) {
        let container = try await MainActor.run {
            try Persistence.makeContainer(inMemory: true)
        }
        return (container, SwiftDataUnitOfWork(modelContainer: container))
    }

    private func storedAccountCount(in container: ModelContainer) async throws -> Int {
        try await MainActor.run {
            try ModelContext(container).fetchCount(FetchDescriptor<AccountRecord>())
        }
    }

    private func storedTransactionCount(in container: ModelContainer) async throws -> Int {
        try await MainActor.run {
            try ModelContext(container).fetchCount(FetchDescriptor<TransactionRecord>())
        }
    }
}
