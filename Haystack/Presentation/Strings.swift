extension AccountType {
    var title: String {
        switch self {
        case .cash: "Cash"
        case .debitCard: "Debit Card"
        case .savings: "Savings"
        }
    }
}
