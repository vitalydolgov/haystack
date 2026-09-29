import Foundation
import Testing
@testable import Haystack

struct AccountTests {
    // MARK: Identity

    @Test func sameIDMeansEqual() throws {
        let id = UUID()
        let left = try Account.make(id: id, name: "Wallet", type: .cash)
        let right = try Account.make(
            id: id,
            name: "Checking",
            type: .debitCard,
            notes: "changed"
        )

        #expect(left == right)
    }

    @Test func differentIDsAreNotEqual() throws {
        let left = try Account.make()
        let right = try Account.make()

        #expect(left != right)
    }

    // MARK: Name

    @Test func trimsNameOnInitAndRename() throws {
        var account = try Account.make(name: "  Wallet  ")
        #expect(account.name == "Wallet")
        try account.rename("  Cash  ")
        #expect(account.name == "Cash")
    }

    @Test(arguments: ["", "   "])
    func rejectsABlankNameOnInit(name: String) {
        #expect(throws: AccountError.blankName) {
            try Account.make(name: name)
        }
    }

    @Test(arguments: ["", "   "])
    func rejectsABlankNameOnRename(name: String) throws {
        var account = try Account.make()
        #expect(throws: AccountError.blankName) {
            try account.rename(name)
        }
        #expect(account.name == "Wallet")
    }

    // MARK: Closed

    @Test func startsOpen() throws {
        let account = try Account.make()
        #expect(!account.isClosed)
    }

    // MARK: Close

    @Test func closesWhenBalanceIsZero() throws {
        var account = try Account.make()
        try account.close()
        #expect(account.isClosed)
    }

    @Test func doesNotThrowWhenAlreadyClosed() throws {
        var account = try Account.make(isClosed: true)
        try account.close()
        #expect(account.isClosed)
    }

    @Test func failsWhenBalanceIsNonZero() throws {
        var account = try Account.make(balance: 10)
        #expect(throws: AccountError.nonZeroBalance) {
            try account.close()
        }
        #expect(!account.isClosed)
    }

    // MARK: Reopen

    @Test func reopensAClosedAccount() throws {
        var account = try Account.make(isClosed: true)
        account.reopen()
        #expect(!account.isClosed)
    }

    @Test func leavesAnOpenAccountOpen() throws {
        var account = try Account.make()
        account.reopen()
        #expect(!account.isClosed)
    }

    // MARK: Delete

    @Test func recordsDeletedAtWhenClosed() throws {
        let account = try Account.make(isClosed: true)
        let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let deleted = try account.delete(at: deletedAt)
        #expect(deleted.id == account.id)
        #expect(deleted.deletedAt == deletedAt)
    }

    @Test func failsWhenOpen() throws {
        let account = try Account.make()
        #expect(throws: AccountError.open) {
            try account.delete()
        }
    }
}
