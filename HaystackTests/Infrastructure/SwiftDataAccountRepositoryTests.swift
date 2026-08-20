import Foundation
import SwiftData
import Testing
@testable import Haystack

struct SwiftDataAccountRepositoryTests {
    // MARK: - Save

    @Test func roundTripsAllFields() async throws {
        let container = try await makeContainer()
        let writer = SwiftDataAccountRepository(modelContainer: container)
        let account = try Account.make(
            name: "Wallet",
            type: .debitCard,
            notes: "Pocket cash",
            balance: 42,
            isClosed: true
        )
        let other = try Account.make(
            name: "Checking",
            type: .savings,
            notes: "Bank",
            balance: 10
        )
        try await writer.save(account)
        try await writer.save(other)

        let reader = SwiftDataAccountRepository(modelContainer: container)
        let stored = try #require(await reader.find(id: account.id))
        #expect(stored.id == account.id)
        #expect(stored.name == "Wallet")
        #expect(stored.type == .debitCard)
        #expect(stored.notes == "Pocket cash")
        #expect(stored.balance == 42)
        #expect(stored.isClosed == true)

        let otherStored = try #require(await reader.find(id: other.id))
        #expect(otherStored.name == "Checking")
        #expect(otherStored.type == .savings)
        #expect(otherStored.notes == "Bank")
        #expect(otherStored.balance == 10)
        #expect(otherStored.isClosed == false)
    }

    @Test func updatesAnExistingAccountInPlace() async throws {
        let container = try await makeContainer()
        let writer = SwiftDataAccountRepository(modelContainer: container)
        let account = try Account.make(type: .debitCard, notes: "Pocket cash", balance: 42)
        let other = try Account.make(name: "Checking", type: .savings, notes: "Bank", balance: 10)
        try await writer.save(account)
        try await writer.save(other)

        var updated = try #require(await writer.find(id: account.id))
        try updated.rename("Cash")
        updated.type = .cash
        updated.notes = "On hand"
        try updated.adjustBalance(to: 10)
        try await writer.save(updated)

        let reader = SwiftDataAccountRepository(modelContainer: container)
        let stored = try #require(await reader.find(id: account.id))
        #expect(stored.name == "Cash")
        #expect(stored.type == .cash)
        #expect(stored.notes == "On hand")
        #expect(stored.balance == 10)
        #expect(stored.isClosed == false)

        let otherStored = try #require(await reader.find(id: other.id))
        #expect(otherStored.name == "Checking")
        #expect(otherStored.type == .savings)
        #expect(otherStored.notes == "Bank")
        #expect(otherStored.balance == 10)
        #expect(otherStored.isClosed == false)
    }

    // MARK: - Find

    @Test func returnsNilWhenMissing() async throws {
        let container = try await makeContainer()
        let writer = SwiftDataAccountRepository(modelContainer: container)
        let account = try Account.make(type: .debitCard, notes: "Pocket cash")
        let other = try Account.make(name: "Checking", type: .savings, notes: "Bank")
        try await writer.save(account)
        try await writer.save(other)

        let reader = SwiftDataAccountRepository(modelContainer: container)
        #expect(await reader.find(id: UUID()) == nil)
        #expect(await reader.find(id: account.id) != nil)
        #expect(await reader.find(id: other.id) != nil)
    }

    // MARK: - Delete

    @Test func removesTheAccount() async throws {
        let container = try await makeContainer()
        let writer = SwiftDataAccountRepository(modelContainer: container)
        let account = try Account.make(type: .debitCard, notes: "Pocket cash")
        let other = try Account.make(name: "Checking", type: .savings, notes: "Bank")
        try await writer.save(account)
        try await writer.save(other)

        try await writer.delete(account)

        let reader = SwiftDataAccountRepository(modelContainer: container)
        #expect(await reader.find(id: account.id) == nil)
        let otherStored = try #require(await reader.find(id: other.id))
        #expect(otherStored.name == "Checking")
        #expect(otherStored.type == .savings)
        #expect(otherStored.notes == "Bank")
        #expect(otherStored.balance == 0)
        #expect(otherStored.isClosed == false)
    }

    @Test func doesNotThrowWhenMissing() async throws {
        let container = try await makeContainer()
        let writer = SwiftDataAccountRepository(modelContainer: container)
        let account = try Account.make(type: .debitCard, notes: "Pocket cash")
        try await writer.save(account)

        try await writer.delete(try Account.make(name: "Missing"))

        let reader = SwiftDataAccountRepository(modelContainer: container)
        let stored = try #require(await reader.find(id: account.id))
        #expect(stored.name == "Wallet")
        #expect(stored.type == .debitCard)
        #expect(stored.notes == "Pocket cash")
        #expect(stored.balance == 0)
        #expect(stored.isClosed == false)
    }

    private func makeContainer() async throws -> ModelContainer {
        try await MainActor.run {
            try Persistence.makeContainer(inMemory: true)
        }
    }
}
