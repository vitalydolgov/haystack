import Foundation
import Observation

enum Route: Hashable, Sendable {
    case accounts
    case transactions(accountID: UUID)
}

enum Sheet: Hashable, Sendable, Identifiable {
    case addAccount
    case editAccount(accountID: UUID)
    case addTransaction(accountID: UUID)
    case editTransaction(accountID: UUID, transactionID: UUID)

    var id: Self { self }
}

struct NavigationState: Equatable, Hashable, Sendable {
    var root: Route
    var path: [Route]
    var sheet: Sheet?

    init(
        root: Route = .accounts,
        path: [Route] = [],
        sheet: Sheet? = nil
    ) {
        self.root = root
        self.path = path
        self.sheet = sheet
    }
}

@Observable
@MainActor
final class Navigator {
    let root: Route
    var path: [Route]
    var sheet: Sheet?

    init(_ state: NavigationState = NavigationState()) {
        root = state.root
        path = state.path
        sheet = state.sheet
    }

    func push(_ route: Route) {
        path.append(route)
    }

    func present(_ sheet: Sheet) {
        self.sheet = sheet
    }

    func dismissSheet() {
        sheet = nil
    }
}
