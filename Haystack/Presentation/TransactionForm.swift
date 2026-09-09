import SwiftData
import SwiftUI

private enum PickerField: Identifiable {
    case account
    case transfer

    var id: Self { self }
}

struct TransactionForm: View {
    @Binding var amountText: String
    @Binding var isOutflow: Bool
    @Binding var date: Date
    @Binding var notes: String
    @Binding var selectedAccountID: UUID
    @Binding var transferAccountID: UUID

    @State private var picker: PickerField?

    @Query(filter: #Predicate<AccountRecord> { $0.deletedAt == nil && !$0.isClosed })
    private var accounts: [AccountRecord]

    private var transferAccount: AccountRecord? {
        guard selectedAccountID != transferAccountID else { return nil }
        return accounts.first { $0.id == transferAccountID }
    }

    var body: some View {
        Form {
            // TODO: labels for each field
            // TODO: only positive
            // TODO: never empty
            TextField("Amount", text: $amountText)
                .keyboardType(.decimalPad)
            Picker("Direction", selection: $isOutflow) {
                Text("Outflow").tag(true)
                Text("Inflow").tag(false)
            }
            // TODO: payee
            Button {
                picker = .account
            } label: {
                HStack {
                    Text("Account")
                    Spacer()
                    Text(accounts.first { $0.id == selectedAccountID }?.name ?? "None")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            // TODO: allow clearing the transfer account (None)
            Button {
                picker = .transfer
            } label: {
                HStack {
                    Text("Transfer")
                    Spacer()
                    Group {
                        if let transferAccount {
                            Text("\(isOutflow ? "To" : "From"): \(transferAccount.name)")
                        } else {
                            Text("None")
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            DatePicker("Date", selection: $date, in: Date.distantPast...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
            // TODO: allow scheduling in the future
            Section {
                // TODO: memo
            }
        }
        .sheet(item: $picker) { field in
            switch field {
            case .account:
                AccountPicker(selectedID: $selectedAccountID)
            case .transfer:
                AccountPicker(selectedID: $transferAccountID)
            }
        }
        .onChange(of: selectedAccountID) { oldValue, newValue in
            if transferAccountID == oldValue {
                transferAccountID = newValue
            } else if newValue == transferAccountID {
                transferAccountID = oldValue
            }
        }
    }
}
