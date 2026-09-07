import Foundation
import SwiftData

actor SwiftDataUnitOfWork: UnitOfWork, ModelActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
    }

    func commit() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }

    func rollback() {
        guard modelContext.hasChanges else { return }
        modelContext.rollback()
    }
}
