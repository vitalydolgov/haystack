import Foundation
import Testing
@testable import Haystack

struct AccountTests {
    // MARK: - Equality

    @Test func sameIDMeansEqual() throws {
        let id = UUID()
        let left = try Account.make(id: id, name: "Wallet", type: .cash, balance: 10)
        let right = try Account.make(
            id: id,
            name: "Checking",
            type: .debitCard,
            notes: "changed",
            balance: 99
        )

        #expect(left == right)
    }

    @Test func differentIDsAreNotEqual() throws {
        let left = try Account.make()
        let right = try Account.make()

        #expect(left != right)
    }

    // MARK: - Name

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

    // MARK: - Close

    @Test func closesWhenBalanceIsZero() throws {
        var account = try Account.make()
        try account.close()
        #expect(account.isClosed)
    }

    @Test func failsWhenBalanceIsNonZero() throws {
        var account = try Account.make(balance: 10)
        #expect(throws: AccountError.nonZeroBalance) {
            try account.close()
        }
        #expect(!account.isClosed)
        #expect(account.balance == 10)
    }

    @Test func doesNotThrowWhenAlreadyClosed() throws {
        var account = try Account.make(isClosed: true)
        try account.close()
        #expect(account.isClosed)
    }

    // MARK: - Reopen

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

    // MARK: - Balance

    @Test func adjustsWhenOpen() throws {
        var account = try Account.make()
        try account.adjustBalance(to: 25)
        #expect(account.balance == 25)
        #expect(!account.isClosed)
    }

    @Test func failsWhenClosed() throws {
        var account = try Account.make(isClosed: true)
        #expect(throws: AccountError.closed) {
            try account.adjustBalance(to: 10)
        }
        #expect(account.balance == 0)
        #expect(account.isClosed)
    }

    // MARK: - Delete

    @Test func allowsDeleteWhenClosed() throws {
        let account = try Account.make(type: .debitCard, notes: "Retired", isClosed: true)
        try account.delete()
        #expect(account.name == "Wallet")
        #expect(account.type == .debitCard)
        #expect(account.notes == "Retired")
        #expect(account.balance == 0)
        #expect(account.isClosed)
    }

    @Test func failsWhenOpen() throws {
        let account = try Account.make()
        #expect(throws: AccountError.open) {
            try account.delete()
        }
        #expect(!account.isClosed)
    }
}
