import Foundation
import Testing
@testable import Haystack

@MainActor
struct HaystackTests {
    @Test func itemStoresTimestamp() {
        let timestamp = Date(timeIntervalSince1970: 0)
        let item = Item(timestamp: timestamp)
        #expect(item.timestamp == timestamp)
    }
}
