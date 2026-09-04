import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petrimonium_health/core/app/health_scope.dart';
import 'package:petrimonium_health/core/i18n/locale_controller.dart';
import 'package:petrimonium_health/core/money/money.dart';
import 'package:petrimonium_health/core/profile/health_profile.dart';
import 'package:petrimonium_health/features/health/data/health_repository.dart';
import 'package:petrimonium_health/features/health/domain/health_models.dart';
import 'package:petrimonium_health/features/health/presentation/health_controller.dart';
import 'package:petrimonium_health/features/transactions/presentation/transactions_screen.dart';
import 'package:petrimonium_health/l10n/app_localizations.dart';

void main() {
  testWidgets('editing a recurrence keeps its billing day and start date', (
    tester,
  ) async {
    final repository = _RecurrenceRepository();
    final controller = HealthController(
      repository: repository,
      localeController: LocaleController(),
    );
    // refreshData() is a no-op until a profile is loaded, so go through the
    // same entry point onboarding uses.
    await controller.saveOnboarding(
      const HealthProfile(
        country: CountryCode.brazil,
        primaryCurrency: CurrencyCode.brl,
        interfaceLocale: InterfaceLocale.ptBr,
      ),
    );
    expect(controller.recurrences, hasLength(1));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: HealthScope(
            controller: controller,
            child: const TransactionsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the recurrences section and edit the only entry.
    await tester.tap(find.text('Repetir mensalmente'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar esta e as futuras').last);
    await tester.pumpAndSettle();

    // Change only the amount, exactly as a user raising the rent would.
    await tester.enterText(
      find.widgetWithText(TextField, 'Valor').last,
      '1950,00',
    );
    await tester.tap(find.text('Salvar').last);
    await tester.pumpAndSettle();

    final saved = repository.updated;
    expect(saved, isNotNull, reason: 'the edit reached the repository');
    expect(saved!.amount.toDecimalString(), '1950.00');
    // Rent charged on the 10th must stay on the 10th: seeding the dialog from
    // startDate instead would show — and then save — day 1.
    expect(saved.dayOfMonth, 10, reason: 'billing day survives an edit');
    expect(
      saved.startDate,
      DateTime(2026, 9, 1),
      reason: 'editing an amount must not move when the series began',
    );
  });
}

final _rent = HealthRecurrence(
  id: 1,
  accountId: 1,
  type: TransactionType.expense,
  amount: Money.fromDecimal('1800.00', CurrencyCode.brl),
  description: 'Aluguel',
  category: 'Moradia',
  dayOfMonth: 10,
  startDate: DateTime(2026, 9, 1),
);

class _RecurrenceRepository implements HealthRepository {
  HealthRecurrence? updated;

  @override
  Future<HealthRecurrence> updateRecurrence(HealthRecurrence recurrence) async {
    updated = recurrence;
    return recurrence;
  }

  @override
  Future<HealthProfile> saveProfile(HealthProfile profile) async => profile;

  @override
  Future<List<HealthRecurrence>> getRecurrences() async => [_rent];

  @override
  Future<List<HealthAccount>> getAccounts() async => [
    HealthAccount(
      id: 1,
      name: 'Conta Corrente',
      type: AccountType.checking,
      initialBalance: Money.fromDecimal('0.00', CurrencyCode.brl),
      balanceReferenceDate: DateTime(2026, 9, 1),
      currentBalance: Money.fromDecimal('0.00', CurrencyCode.brl),
      archived: false,
    ),
  ];

  @override
  Future<List<HealthCard>> getCards() async => const [];

  @override
  Future<List<HealthTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    int? accountId,
    String? category,
    TransactionStatus? status,
  }) async => const [];

  @override
  Future<MonthlySummary> getSummary(DateTime month) async =>
      MonthlySummary.empty(CurrencyCode.brl, month);

  @override
  Future<HealthProfile?> getProfile() async => const HealthProfile(
    country: CountryCode.brazil,
    primaryCurrency: CurrencyCode.brl,
    interfaceLocale: InterfaceLocale.ptBr,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
