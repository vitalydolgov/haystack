import SwiftUI
import SwiftData

// TODO: make "None" option
struct AccountPicker: View {
    @Query(filter: #Predicate<AccountRecord> { $0.deletedAt == nil && !$0.isClosed }, sort: \AccountRecord.name)
    private var accounts: [AccountRecord]
    @Binding var selectedID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(accounts) { account in
                // TODO: whole row should be tappable
                Button {
                    selectedID = account.id
                    dismiss()
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", action: dismiss.callAsFunction)
                        .labelStyle(.iconOnly)
                }
            }
        }
    }
}
