import Foundation
import SwiftData
import Testing
@testable import Haystack

struct SwiftDataAccountRepositoryTests {
    // MARK: Save

    @Test func roundTripsAllFields() async throws {
        let (container, writer) = try await makeStore()
        let account = try Account.make(
            name: "Wallet",
            type: .debitCard,
            notes: "Pocket cash",
            balance: 42,
            isClosed: true
        )
        try await writer.save(account)

        let stored = try #require(try await reader(container).query(id: account.id))
        #expect(stored.id == account.id)
        #expect(stored.name == "Wallet")
        #expect(stored.type == .debitCard)
        #expect(stored.notes == "Pocket cash")
        #expect(stored.balance == 42)
        #expect(stored.isClosed == true)
    }

    @Test func updatesAnExistingAccountInPlace() async throws {
        let (container, writer) = try await makeStore()
        var account = try Account.make(type: .debitCard, notes: "Pocket cash")
        try await writer.save(account)

        try account.rename("Cash")
        account.type = .cash
        account.notes = "On hand"
        try await writer.save(account)

        let stored = try #require(try await reader(container).query(id: account.id))
        #expect(stored.name == "Cash")
        #expect(stored.type == .cash)
        #expect(stored.notes == "On hand")
    }

    @Test func updatesBalance() async throws {
        let (container, writer) = try await makeStore()
        let account = try Account.make(balance: 10)
        try await writer.save(account)
        let updated = try Account.make(id: account.id, name: "Cash", balance: 4)
        try await writer.save(updated)

        let stored = try #require(try await reader(container).query(id: account.id))
        #expect(stored.name == "Cash")
        #expect(stored.balance == 4)
    }

    @Test func storesAccountsSeparately() async throws {
        let (_, accounts) = try await makeStore()
        let wallet = try Account.make(name: "Wallet")
        let checking = try Account.make(name: "Checking")
        try await accounts.save(wallet)
        try await accounts.save(checking)

        #expect(try await accounts.query(id: wallet.id)?.name == "Wallet")
        #expect(try await accounts.query(id: checking.id)?.name == "Checking")
    }

    @Test func doesNotResurrectADeletedAccount() async throws {
        let (_, accounts) = try await makeStore()
        let account = try Account.make(isClosed: true)
        try await accounts.save(account)
        let deleted = try account.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        try await accounts.delete(deleted)
        try await accounts.save(account)

        #expect(try await accounts.query(id: account.id) == nil)
    }

    // MARK: Query

    @Test func findsALiveAccount() async throws {
        let (container, writer) = try await makeStore()
        let account = try Account.make()
        try await writer.save(account)

        #expect(try await reader(container).query(id: account.id) != nil)
    }

    @Test func hidesADeletedAccount() async throws {
        let (_, accounts) = try await makeStore()
        let account = try Account.make(isClosed: true)
        try await accounts.save(account)
        let deleted = try account.delete(at: Date(timeIntervalSince1970: 1_700_000_000))
        try await accounts.delete(deleted)

        #expect(try await accounts.query(id: account.id) == nil)
    }

    @Test func returnsNilWhenMissing() async throws {
        let (_, accounts) = try await makeStore()
        #expect(try await accounts.query(id: UUID()) == nil)
    }

    // MARK: Delete

    @Test func persistsADeletedAccount() async throws {
        let (container, accounts) = try await makeStore()
        let account = try Account.make(isClosed: true)
        try await accounts.save(account)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let deleted = try account.delete(at: deletedAt)
        try await accounts.delete(deleted)

        #expect(try await storedDeletedAt(id: account.id, in: container) == deletedAt)
    }

    @Test func doesNotOverwriteDeletedAt() async throws {
        let (container, accounts) = try await makeStore()
        let account = try Account.make(isClosed: true)
        try await accounts.save(account)
        let original = Date(timeIntervalSince1970: 1)
        let deleted = try account.delete(at: original)
        try await accounts.delete(deleted)
        try await accounts.delete(DeletedAccount(id: account.id, deletedAt: Date(timeIntervalSince1970: 2)))

        #expect(try await storedDeletedAt(id: account.id, in: container) == original)
    }

    @Test func doesNothingWhenMissing() async throws {
        let (container, accounts) = try await makeStore()
        let id = UUID()
        try await accounts.delete(DeletedAccount(id: id, deletedAt: Date(timeIntervalSince1970: 1_700_000_000)))

        #expect(try await storedDeletedAt(id: id, in: container) == nil)
    }

    // MARK: - Helpers

    private func makeStore() async throws -> (ModelContainer, DurableAccountRepository) {
        let container = try await MainActor.run {
            try Persistence.makeContainer(inMemory: true)
        }
        return (container, DurableAccountRepository(modelContainer: container))
    }

    private func reader(_ container: ModelContainer) -> DurableAccountRepository {
        DurableAccountRepository(modelContainer: container)
    }

    private func storedDeletedAt(id: UUID, in container: ModelContainer) async throws -> Date? {
        try await MainActor.run {
            let context = ModelContext(container)
            let accountID = id
            var descriptor = FetchDescriptor<AccountRecord>(
                predicate: #Predicate { $0.id == accountID }
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.deletedAt
        }
    }
}
