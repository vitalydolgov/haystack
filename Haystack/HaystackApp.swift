import SwiftData
import SwiftUI

@main
struct HaystackApp: App {
    let container: ModelContainer
    let accountRepository: SwiftDataAccountRepository
    let transactionRepository: SwiftDataTransactionRepository

    init() {
        do {
            let container = try Persistence.makeContainer()
            self.container = container
            self.accountRepository = SwiftDataAccountRepository(modelContainer: container)
            self.transactionRepository = SwiftDataTransactionRepository(modelContainer: container)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AccountsView()
                .environment(\.accountRepository, accountRepository)
                .environment(\.transactionRepository, transactionRepository)
        }
        .modelContainer(container)
    }
}
