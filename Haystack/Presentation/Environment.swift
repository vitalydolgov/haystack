import SwiftUI

extension EnvironmentValues {
    @Entry var accountRepository: (any AccountRepository)?
    @Entry var transactionRepository: (any TransactionRepository)?
}
