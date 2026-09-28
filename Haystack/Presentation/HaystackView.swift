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
            AddTransactionSheet(accountID: accountID)
        case .editTransaction(let accountID, let transactionID):
            EditTransactionSheet(accountID: accountID, mode: .plain(transactionID))
        case .editTransfer(let accountID, let transferID):
            EditTransactionSheet(accountID: accountID, mode: .transfer(transferID))
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
