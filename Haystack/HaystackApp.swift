import SwiftData
import SwiftUI

@main
struct HaystackApp: App {
    let container: ModelContainer
    let unitOfWork: SwiftDataUnitOfWork
    let accountRepository: SwiftDataAccountRepository
    let transactionRepository: SwiftDataTransactionRepository

    init() {
        do {
            let container = try Persistence.makeContainer()
            self.container = container
            self.unitOfWork = SwiftDataUnitOfWork(modelContainer: container)
            self.accountRepository = SwiftDataAccountRepository(
                modelContainer: unitOfWork.modelContainer,
                modelExecutor: unitOfWork.modelExecutor
            )
            self.transactionRepository = SwiftDataTransactionRepository(modelContainer: container)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HaystackView()
                .environment(\.unitOfWork, unitOfWork)
                .environment(\.accountRepository, accountRepository)
                .environment(\.transactionRepository, transactionRepository)
        }
        .modelContainer(container)
    }
}
