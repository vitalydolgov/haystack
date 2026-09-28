import SwiftUI

extension EnvironmentValues {
    @Entry var unitOfWork: (any UnitOfWork)?
    // TODO: make accountRepository required
    @Entry var accountRepository: (any AccountQuerying)?
    // TODO: make transactionRepository required
    @Entry var transactionRepository: (any TransactionQuerying)?
}
