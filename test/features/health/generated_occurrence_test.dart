import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petrimonium_health/core/i18n/locale_controller.dart';
import 'package:petrimonium_health/core/money/money.dart';
import 'package:petrimonium_health/core/profile/health_profile.dart';
import 'package:petrimonium_health/features/health/data/health_repository.dart';
import 'package:petrimonium_health/features/health/domain/health_models.dart';
import 'package:petrimonium_health/features/health/presentation/health_controller.dart';

/// A monthly commitment exists twice in the data: as the recurrence the user
/// created, and as the PLANNED occurrence the backend generates from it for
/// the month. The summary lists recurrences and one-off entries side by side,
/// so the generated occurrence must not be counted as a second, separate
/// commitment -- otherwise a single 1500 salary reads as 3000 on the screen
/// that is meant to explain the projection.
void main() {
  late HealthController controller;

  setUp(() async {
    // LocaleController persists the chosen locale; give it a store to write to.
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    controller = HealthController(
      repository: _Repository(),
      localeController: LocaleController(),
    );
    // refreshData() is a no-op until a profile is loaded, so go through the
    // same entry point onboarding uses.
    await controller.saveOnboarding(
      const HealthProfile(
        country: CountryCode.portugal,
        primaryCurrency: CurrencyCode.eur,
        interfaceLocale: InterfaceLocale.ptPt,
      ),
    );
  });

  test('a generated occurrence is not listed as a one-off income', () {
    expect(controller.incomeRecurrences, hasLength(1));
    expect(
      controller.oneOffIncomes.map((t) => t.description),
      ['Prémio'],
      reason: 'only the hand-entered income is a one-off',
    );
  });

  test('a generated occurrence is not listed as a one-off debt', () {
    expect(controller.debtRecurrences, hasLength(1));
    expect(
      controller.oneOffDebts.map((t) => t.description),
      ['Dentista'],
      reason: 'only the hand-entered commitment is a one-off',
    );
  });
}

Money _eur(String amount) => Money.fromDecimal(amount, CurrencyCode.eur);

HealthTransaction _planned({
  required int id,
  required TransactionType type,
  required String description,
  required String category,
  int? recurrenceId,
}) =>
    HealthTransaction(
      id: id,
      accountId: 1,
      type: type,
      status: TransactionStatus.planned,
      amount: _eur('1500.00'),
      description: description,
      category: category,
      date: DateTime(2026, 9, 7),
      recurrenceId: recurrenceId,
    );

class _Repository implements HealthRepository {
  @override
  Future<HealthProfile> saveProfile(HealthProfile profile) async => profile;

  @override
  Future<HealthProfile?> getProfile() async => const HealthProfile(
        country: CountryCode.portugal,
        primaryCurrency: CurrencyCode.eur,
        interfaceLocale: InterfaceLocale.ptPt,
      );

  @override
  Future<List<HealthAccount>> getAccounts() async => [
        HealthAccount(
          id: 1,
          name: 'Conta à ordem',
          type: AccountType.checking,
          initialBalance: _eur('850.00'),
          balanceReferenceDate: DateTime(2026, 9, 1),
          currentBalance: _eur('850.00'),
          archived: false,
        ),
      ];

  @override
  Future<List<HealthRecurrence>> getRecurrences() async => [
        HealthRecurrence(
          id: 1,
          accountId: 1,
          type: TransactionType.income,
          amount: _eur('1500.00'),
          description: 'Ordenado',
          category: 'INCOME_SALARY',
          dayOfMonth: 7,
          startDate: DateTime(2026, 9, 7),
        ),
        HealthRecurrence(
          id: 2,
          accountId: 1,
          type: TransactionType.expense,
          amount: _eur('1500.00'),
          description: 'Renda',
          category: 'DEBT_HOME_FINANCING',
          dayOfMonth: 8,
          startDate: DateTime(2026, 9, 8),
        ),
      ];

  @override
  Future<List<HealthTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    int? accountId,
    String? category,
    TransactionStatus? status,
  }) async =>
      [
        // What the backend generated from the two recurrences above.
        _planned(
          id: 10,
          type: TransactionType.income,
          description: 'Ordenado',
          category: 'INCOME_SALARY',
          recurrenceId: 1,
        ),
        _planned(
          id: 11,
          type: TransactionType.expense,
          description: 'Renda',
          category: 'DEBT_HOME_FINANCING',
          recurrenceId: 2,
        ),
        // What the user entered by hand.
        _planned(
          id: 12,
          type: TransactionType.income,
          description: 'Prémio',
          category: 'INCOME_OTHER',
        ),
        _planned(
          id: 13,
          type: TransactionType.expense,
          description: 'Dentista',
          category: 'DEBT_OTHER',
        ),
      ];

  @override
  Future<List<HealthCard>> getCards() async => const [];

  @override
  Future<MonthlySummary> getSummary(DateTime month) async =>
      MonthlySummary.empty(CurrencyCode.eur, month);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
