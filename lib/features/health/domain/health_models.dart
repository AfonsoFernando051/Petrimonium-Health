import '../../../core/money/money.dart';

DateTime _date(Object? value) => DateTime.parse(value as String);
int _id(Object? value) => (value as num).toInt();

enum AccountType {
  checking('CHECKING'),
  savings('SAVINGS'),
  cash('CASH'),
  other('OTHER');

  const AccountType(this.apiValue);
  final String apiValue;

  static AccountType parse(String value) => values.firstWhere(
    (type) => type.apiValue == value,
    orElse: () => AccountType.other,
  );
}

final class HealthAccount {
  const HealthAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.balanceReferenceDate,
    required this.currentBalance,
    required this.archived,
  });

  factory HealthAccount.fromJson(Map<String, dynamic> json) {
    final currency = CurrencyCode.parse(json['currency'] as String);
    return HealthAccount(
      id: _id(json['id']),
      name: json['name'] as String,
      type: AccountType.parse(json['type'] as String),
      initialBalance: Money.fromDecimal(
        json['initialBalance'] as String,
        currency,
      ),
      balanceReferenceDate: _date(json['balanceReferenceDate']),
      currentBalance: Money.fromDecimal(
        json['currentBalance'] as String,
        currency,
      ),
      archived: json['archived'] as bool? ?? false,
    );
  }

  final int id;
  final String name;
  final AccountType type;
  final Money initialBalance;
  final DateTime balanceReferenceDate;
  final Money currentBalance;
  final bool archived;

  CurrencyCode get currency => currentBalance.currency;
}

enum TransactionType {
  income('INCOME'),
  expense('EXPENSE'),
  transferIn('TRANSFER_IN'),
  transferOut('TRANSFER_OUT'),
  invoicePayment('INVOICE_PAYMENT'),
  other('OTHER');

  const TransactionType(this.apiValue);
  final String apiValue;

  static TransactionType parse(String value) => values.firstWhere(
    (type) => type.apiValue == value,
    orElse: () => TransactionType.other,
  );
}

enum TransactionStatus {
  planned('PLANNED'),
  realized('REALIZED');

  const TransactionStatus(this.apiValue);
  final String apiValue;

  static TransactionStatus parse(String value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => throw FormatException('Unsupported status: $value'),
  );
}

final class HealthTransaction {
  const HealthTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.status,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    this.source = 'MANUAL',
    this.transferId,
    this.recurrenceId,
    this.invoiceId,
  });

  factory HealthTransaction.fromJson(Map<String, dynamic> json) {
    final currency = CurrencyCode.parse(json['currency'] as String);
    return HealthTransaction(
      id: _id(json['id']),
      accountId: _id(json['accountId']),
      type: TransactionType.parse(json['type'] as String),
      status: TransactionStatus.parse(json['status'] as String),
      amount: Money.fromDecimal(json['amount'] as String, currency),
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      date: _date(json['date']),
      source: json['source'] as String? ?? 'MANUAL',
      transferId: json['transferId'] == null ? null : _id(json['transferId']),
      recurrenceId: json['recurrenceId'] == null
          ? null
          : _id(json['recurrenceId']),
      invoiceId: json['invoiceId'] == null ? null : _id(json['invoiceId']),
    );
  }

  final int id;
  final int accountId;
  final TransactionType type;
  final TransactionStatus status;
  final Money amount;
  final String description;
  final String category;
  final DateTime date;
  final String source;
  final int? transferId;
  final int? recurrenceId;
  final int? invoiceId;

  bool get isSystemEntry =>
      source != 'MANUAL' ||
      transferId != null ||
      recurrenceId != null ||
      invoiceId != null;
}

final class HealthCard {
  const HealthCard({
    required this.id,
    required this.name,
    required this.currency,
    required this.closingDay,
    required this.dueDay,
    required this.archived,
  });

  factory HealthCard.fromJson(Map<String, dynamic> json) => HealthCard(
    id: _id(json['id']),
    name: json['name'] as String,
    currency: CurrencyCode.parse(json['currency'] as String),
    closingDay: (json['closingDay'] as num).toInt(),
    dueDay: (json['dueDay'] as num).toInt(),
    archived: json['archived'] as bool? ?? false,
  );

  final int id;
  final String name;
  final CurrencyCode currency;
  final int closingDay;
  final int dueDay;
  final bool archived;
}

final class CardInvoice {
  const CardInvoice({
    required this.id,
    required this.cardId,
    required this.currency,
    required this.amount,
    required this.dueDate,
    required this.paid,
  });

  factory CardInvoice.fromJson(Map<String, dynamic> json) {
    final currency = CurrencyCode.parse(json['currency'] as String);
    return CardInvoice(
      id: _id(json['id']),
      cardId: _id(json['cardId']),
      currency: currency,
      amount: Money.fromDecimal(
        (json['amount'] ?? json['totalAmount']) as String,
        currency,
      ),
      dueDate: _date(json['dueDate']),
      paid:
          json['paid'] as bool? ??
          ((json['status'] as String?)?.toUpperCase() == 'PAID'),
    );
  }

  final int id;
  final int cardId;
  final CurrencyCode currency;
  final Money amount;
  final DateTime dueDate;
  final bool paid;
}

final class CategoryExpense {
  const CategoryExpense({required this.category, required this.amount});

  factory CategoryExpense.fromJson(
    Map<String, dynamic> json,
    CurrencyCode currency,
  ) => CategoryExpense(
    category: json['category'] as String,
    amount: Money.fromDecimal(json['amount'] as String, currency),
  );

  final String category;
  final Money amount;
}

final class UpcomingCommitment {
  const UpcomingCommitment({
    required this.description,
    required this.amount,
    required this.date,
  });

  factory UpcomingCommitment.fromJson(
    Map<String, dynamic> json,
    CurrencyCode currency,
  ) => UpcomingCommitment(
    description: json['description'] as String? ?? '',
    amount: Money.fromDecimal(json['amount'] as String, currency),
    date: _date(json['date'] ?? json['dueDate']),
  );

  final String description;
  final Money amount;
  final DateTime date;
}

final class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.currency,
    required this.currentBalance,
    required this.realizedIncome,
    required this.realizedExpenses,
    required this.plannedIncome,
    required this.plannedExpenses,
    required this.openCardInvoices,
    required this.monthResult,
    required this.projectedEndBalance,
    required this.expensesByCategory,
    required this.upcoming,
  });

  factory MonthlySummary.empty(CurrencyCode currency, DateTime month) =>
      MonthlySummary(
        month: DateTime(month.year, month.month),
        currency: currency,
        currentBalance: Money.zero(currency),
        realizedIncome: Money.zero(currency),
        realizedExpenses: Money.zero(currency),
        plannedIncome: Money.zero(currency),
        plannedExpenses: Money.zero(currency),
        openCardInvoices: Money.zero(currency),
        monthResult: Money.zero(currency),
        projectedEndBalance: Money.zero(currency),
        expensesByCategory: const [],
        upcoming: const [],
      );

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    final currency = CurrencyCode.parse(json['currency'] as String);
    Money amount(String key) =>
        Money.fromDecimal(json[key] as String, currency);
    final rawMonth = json['month'] as String;
    final month = DateTime.parse('$rawMonth-01');
    return MonthlySummary(
      month: month,
      currency: currency,
      currentBalance: amount('currentBalance'),
      realizedIncome: amount('realizedIncome'),
      realizedExpenses: amount('realizedExpenses'),
      plannedIncome: amount('plannedIncome'),
      plannedExpenses: amount('plannedExpenses'),
      openCardInvoices: amount('openCardInvoices'),
      monthResult: amount('monthResult'),
      projectedEndBalance: amount('projectedEndBalance'),
      expensesByCategory: ((json['expensesByCategory'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((item) => CategoryExpense.fromJson(item, currency))
          .toList(growable: false),
      upcoming: ((json['upcoming'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((item) => UpcomingCommitment.fromJson(item, currency))
          .toList(growable: false),
    );
  }

  final DateTime month;
  final CurrencyCode currency;
  final Money currentBalance;
  final Money realizedIncome;
  final Money realizedExpenses;
  final Money plannedIncome;
  final Money plannedExpenses;
  final Money openCardInvoices;
  final Money monthResult;
  final Money projectedEndBalance;
  final List<CategoryExpense> expensesByCategory;
  final List<UpcomingCommitment> upcoming;
}

final class HealthRecurrence {
  const HealthRecurrence({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.description,
    required this.category,
    required this.dayOfMonth,
    required this.startDate,
    this.endDate,
    this.active = true,
  });

  factory HealthRecurrence.fromJson(Map<String, dynamic> json) {
    final currency = CurrencyCode.parse(json['currency'] as String);
    return HealthRecurrence(
      id: _id(json['id']),
      accountId: _id(json['accountId']),
      type: TransactionType.parse(json['type'] as String),
      amount: Money.fromDecimal(json['amount'] as String, currency),
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      dayOfMonth: (json['dayOfMonth'] as num).toInt(),
      startDate: _date(json['startDate']),
      endDate: json['endDate'] == null ? null : _date(json['endDate']),
      active: json['active'] as bool? ?? true,
    );
  }

  final int id;
  final int accountId;
  final TransactionType type;
  final Money amount;
  final String description;
  final String category;
  final int dayOfMonth;
  final DateTime startDate;
  final DateTime? endDate;

  /// `DELETE /recurrences/{id}` deactivates rather than deletes the row
  /// (docs/API.md: "DELETE desativa a recorrência..."), so `GET /recurrences`
  /// keeps returning it with `active: false` — callers must filter this out
  /// themselves; see `HealthController.debtRecurrences`/`incomeRecurrences`.
  final bool active;
}

/// `GET /api/users/me` — shared identity endpoint (Academy/Wallet/Health all
/// read the same account). Used only for display (greeting, profile
/// header); it is not part of the Health domain itself.
final class AccountIdentity {
  const AccountIdentity({required this.username, required this.email});

  factory AccountIdentity.fromJson(Map<String, dynamic> json) =>
      AccountIdentity(
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );

  final String username;
  final String email;
}

final class PetIdentity {
  const PetIdentity({this.name, this.species});

  factory PetIdentity.fromJson(Map<String, dynamic> json) => PetIdentity(
    name: json['name'] as String?,
    species: (json['specie'] ?? json['species']) as String?,
  );

  final String? name;
  final String? species;
}
