import SwiftUI
import SwiftData

// TODO: make "None" option
struct AccountPicker: View {
    @Query(filter: #Predicate<AccountRecord> { $0.deletedAt == nil && !$0.isClosed }, sort: \AccountRecord.name)
    private var accounts: [AccountRecord]
    @Binding var selectedID: UUID

    var body: some View {
        NavigationStack {
            List(accounts) { account in
                Button {
                    selectedID = account.id
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                            .opacity(account.id == selectedID ? 1 : 0)
                        Text(account.name)
                        Spacer()
                        // TODO: balance
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Account")
        }
    }
}
