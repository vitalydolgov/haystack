import SwiftUI

struct AccountPicker: View {
    @Binding private var selectedID: UUID?

    @State private var accounts: [Account] = []

    @Environment(\.accountRepository) private var accountRepository
    @Environment(\.dismiss) private var dismiss

    init(selectedID: Binding<UUID>) {
        _selectedID = Binding(
            get: { selectedID.wrappedValue },
            set: { newValue in
                if let newValue {
                    selectedID.wrappedValue = newValue
                }
            }
        )
    }

    init(optionalID: Binding<UUID?>) {
        _selectedID = optionalID
    }

    // MARK: Views

    private func accountRow(_ account: Account) -> some View {
        Button {
            selectedID = account.id
            dismiss()
        } label: {
            HStack {
                Image(systemName: "checkmark")
                    .opacity(account.id == selectedID ? 1 : 0)
                Text(account.name)
                Spacer()
                Text(account.balance, format: .currency(code: AmountFormatter.currencyCode))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(accounts) { account in
                    accountRow(account)
                }
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
        .task {
            accounts = await accounts()
        }
    }

    // MARK: Tasks

    private func accounts() async -> [Account] {
        do {
            return try await accountRepository.query(.open)
        } catch {
            print("error: \(error)")
            return []
        }
    }
}
