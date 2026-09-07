import SwiftData
import SwiftUI

@main
struct HaystackApp: App {
    let container: ModelContainer
    let unitOfWork: SwiftDataUnitOfWork

    init() {
        do {
            let container = try Persistence.makeContainer()
            self.container = container
            self.unitOfWork = SwiftDataUnitOfWork(modelContainer: container)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HaystackView()
                .environment(\.unitOfWork, unitOfWork)
                .environment(\.accountRepository, unitOfWork.accounts)
                .environment(\.transactionRepository, unitOfWork.transactions)
        }
        .modelContainer(container)
    }
}
