import Foundation
import SwiftData

@MainActor
enum Persistence {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([AccountRecord.self])
        let configuration = ModelConfiguration(
            inMemory ? UUID().uuidString : "haystack",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
