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
import 'package:petrimonium_health/features/onboarding/presentation/quick_setup_screen.dart';
import 'package:petrimonium_health/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'Portugal suggestion can be overridden and persists independently',
    (tester) async {
      final repository = _OnboardingRepository();
      final controller = HealthController(
        repository: repository,
        localeController: LocaleController(),
      );

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
          home: HealthScope(
            controller: controller,
            child: const QuickSetupScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Portugal'));
      await tester.pump();
      await tester.tap(find.text('BRL — Real brasileiro'));
      await tester.ensureVisible(find.text('Português do Brasil'));
      await tester.pump();
      await tester.tap(find.text('Português do Brasil'));
      await tester.tap(find.text('Começar a organizar meu mês'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.savedProfile?.country, CountryCode.portugal);
      expect(repository.savedProfile?.primaryCurrency, CurrencyCode.brl);
      expect(repository.savedProfile?.interfaceLocale, InterfaceLocale.ptBr);
    },
  );
}

class _OnboardingRepository implements HealthRepository {
  HealthProfile? savedProfile;

  @override
  Future<HealthProfile> saveProfile(HealthProfile profile) async {
    savedProfile = profile;
    return profile;
  }

  @override
  Future<List<HealthAccount>> getAccounts() async => const [];

  @override
  Future<List<HealthCard>> getCards() async => const [];

  @override
  Future<List<HealthRecurrence>> getRecurrences() async => const [];

  @override
  Future<MonthlySummary> getSummary(DateTime month) async =>
      MonthlySummary.empty(savedProfile!.primaryCurrency, month);

  @override
  Future<List<HealthTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    int? accountId,
    String? category,
    TransactionStatus? status,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
