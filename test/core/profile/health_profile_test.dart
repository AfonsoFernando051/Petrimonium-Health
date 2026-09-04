import 'package:flutter_test/flutter_test.dart';
import 'package:petrimonium_health/core/money/money.dart';
import 'package:petrimonium_health/core/profile/health_profile.dart';

void main() {
  test('Brazil suggests BRL and pt-BR', () {
    final suggestion = suggestionFor(CountryCode.brazil);

    expect(suggestion.currency, CurrencyCode.brl);
    expect(suggestion.locale, InterfaceLocale.ptBr);
  });

  test('Portugal suggests EUR and pt-PT', () {
    final suggestion = suggestionFor(CountryCode.portugal);

    expect(suggestion.currency, CurrencyCode.eur);
    expect(suggestion.locale, InterfaceLocale.ptPt);
  });

  test('country currency and locale remain independent in persisted JSON', () {
    const profile = HealthProfile(
      country: CountryCode.portugal,
      primaryCurrency: CurrencyCode.brl,
      interfaceLocale: InterfaceLocale.ptBr,
    );

    final restored = HealthProfile.fromJson(profile.toJson());

    expect(restored.country, CountryCode.portugal);
    expect(restored.primaryCurrency, CurrencyCode.brl);
    expect(restored.interfaceLocale, InterfaceLocale.ptBr);
  });

  test('profile response persists the backend currency lock', () {
    final profile = HealthProfile.fromJson({
      'countryCode': 'BR',
      'primaryCurrency': 'BRL',
      'localeTag': 'pt-BR',
      'currencyChangeAllowed': false,
    });

    expect(profile.currencyChangeAllowed, isFalse);
  });
}
