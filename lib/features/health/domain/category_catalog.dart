/// Health has no dedicated "debt" or "income source" resource in the shared
/// backend — both are represented as ordinary planned transactions
/// (`TransactionType.expense`/`income`, `TransactionStatus.planned`), one-off
/// or recurring. These catalogs give that convention a stable, namespaced
/// `category` value so the Home screen can tell a debt/income entry apart
/// from a regular categorized expense (see docs/FINANCIAL_RULES.md §4, §6).
enum DebtCategory {
  creditCard('DEBT_CREDIT_CARD', '💳'),
  personalLoan('DEBT_PERSONAL_LOAN', '💰'),
  carFinancing('DEBT_CAR_FINANCING', '🚗'),
  homeFinancing('DEBT_HOME_FINANCING', '🏠'),
  payrollLoan('DEBT_PAYROLL_LOAN', '📄'),
  other('DEBT_OTHER', '▦');

  const DebtCategory(this.apiCategory, this.icon);

  final String apiCategory;
  final String icon;

  static DebtCategory? fromApiCategory(String value) {
    for (final category in values) {
      if (category.apiCategory == value) return category;
    }
    return null;
  }
}

enum IncomeCategory {
  salary('INCOME_SALARY', '💼'),
  freelance('INCOME_FREELANCE', '🧾'),
  rental('INCOME_RENTAL', '🏘'),
  other('INCOME_OTHER', '▦');

  const IncomeCategory(this.apiCategory, this.icon);

  final String apiCategory;
  final String icon;

  static IncomeCategory? fromApiCategory(String value) {
    for (final category in values) {
      if (category.apiCategory == value) return category;
    }
    return null;
  }
}
