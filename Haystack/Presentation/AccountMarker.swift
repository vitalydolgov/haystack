import SwiftUI

struct AccountMarker: View {
    let type: AccountType

    var body: some View {
        Image(systemName: "square.fill")
            .foregroundStyle(type.color)
    }
}

private extension AccountType {
    var color: Color {
        switch self {
        case .cash: DeosaiTheme.clover
        case .debitCard: DeosaiTheme.meadow
        case .savings: DeosaiTheme.ridge
        }
    }
}
