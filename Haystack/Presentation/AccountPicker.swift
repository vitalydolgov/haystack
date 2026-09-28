import SwiftUI

// TODO: make "None" option
struct AccountPicker: View {
    @Binding var selectedID: UUID
    @State private var accounts: [Account] = []

    @Environment(\.accountRepository) private var accountRepository
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
        .task {
            accounts = await accounts()
        }
    }

    private func accounts() async -> [Account] {
        do {
            guard let accountRepository else { return [] }
            return try await accountRepository.query(.open)
        } catch {
            print("error: \(error)")
            return []
        }
    }
}
