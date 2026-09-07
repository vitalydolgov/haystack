import SwiftUI

struct HaystackView: View {
    @State private var navigator: Navigator

    init(navigation: NavigationState = NavigationState()) {
        _navigator = State(initialValue: Navigator(navigation))
    }

    var body: some View {
        HaystackNavigation(navigator: navigator)
            .environment(navigator)
    }
}

private struct HaystackNavigation: View {
    @Bindable var navigator: Navigator

    var body: some View {
        NavigationStack(path: $navigator.path) {
            RouteView(route: navigator.root)
                .navigationDestination(for: Route.self) { route in
                    RouteView(route: route)
                }
        }
        .sheet(item: $navigator.sheet, content: sheetView)
    }

    @ViewBuilder
    private func sheetView(_ sheet: Sheet) -> some View {
        switch sheet {
        case .addAccount:
            AddAccountSheet()
        case .editAccount(let accountID):
            EditAccountSheet(accountID: accountID)
        case .addTransaction(let accountID):
            TransactionSheet(accountID: accountID, mode: .add)
        case .editTransaction(let accountID, let transactionID):
            TransactionSheet(accountID: accountID, mode: .edit(transactionID))
        }
    }
}

private struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .accounts:
            AccountsView()
        case .transactions(let accountID):
            TransactionsView(accountID: accountID)
        }
    }
}

#Preview("Accounts") {
    let container = try! Persistence.makeContainer(inMemory: true)
    let unitOfWork = SwiftDataUnitOfWork(modelContainer: container)
    HaystackView()
        .modelContainer(container)
        .environment(\.unitOfWork, unitOfWork)
        .environment(\.accountRepository, SwiftDataAccountRepository(
            modelContainer: unitOfWork.modelContainer,
            modelExecutor: unitOfWork.modelExecutor
        ))
        .environment(\.transactionRepository, SwiftDataTransactionRepository(modelContainer: container))
}

#Preview("Transactions") {
    let container = try! Persistence.makeContainer(inMemory: true)
    let account = try! Account(name: "Wallet", type: .cash)
    let context = container.mainContext
    context.insert(AccountRecord(account))
    context.insert(
        TransactionRecord(
            try! Transaction(
                accountID: account.id,
                date: (year: 2026, month: 9, day: 1),
                amount: 10,
                type: .adjustment
            )
        )
    )
    try! context.save()
    let unitOfWork = SwiftDataUnitOfWork(modelContainer: container)
    return HaystackView(
        navigation: NavigationState(root: .transactions(accountID: account.id))
    )
    .modelContainer(container)
    .environment(\.unitOfWork, unitOfWork)
    .environment(\.accountRepository, SwiftDataAccountRepository(
        modelContainer: unitOfWork.modelContainer,
        modelExecutor: unitOfWork.modelExecutor
    ))
    .environment(\.transactionRepository, SwiftDataTransactionRepository(modelContainer: container))
}
