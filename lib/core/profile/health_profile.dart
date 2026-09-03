import 'package:flutter/widgets.dart';

import '../money/money.dart';

enum CountryCode {
  brazil('BR'),
  portugal('PT');

  const CountryCode(this.code);
  final String code;

  static CountryCode parse(String value) => values.firstWhere(
        (country) => country.code == value.toUpperCase(),
        orElse: () => throw FormatException('Unsupported country: $value'),
      );
}

enum InterfaceLocale {
  ptBr('pt-BR', Locale('pt', 'BR')),
  ptPt('pt-PT', Locale('pt', 'PT'));

  const InterfaceLocale(this.tag, this.locale);
  final String tag;
  final Locale locale;

  static InterfaceLocale parse(String value) => values.firstWhere(
        (item) => item.tag.toLowerCase() == value.replaceAll('_', '-').toLowerCase(),
        orElse: () => throw FormatException('Unsupported locale: $value'),
      );
}

final class RegionalSuggestion {
  const RegionalSuggestion({
    required this.currency,
    required this.locale,
  });

  final CurrencyCode currency;
  final InterfaceLocale locale;
}

RegionalSuggestion suggestionFor(CountryCode country) => switch (country) {
      CountryCode.brazil => const RegionalSuggestion(
          currency: CurrencyCode.brl,
          locale: InterfaceLocale.ptBr,
        ),
      CountryCode.portugal => const RegionalSuggestion(
          currency: CurrencyCode.eur,
          locale: InterfaceLocale.ptPt,
        ),
    };

final class HealthProfile {
  const HealthProfile({
    required this.country,
    required this.primaryCurrency,
    required this.interfaceLocale,
    this.currencyChangeAllowed = true,
  });

  factory HealthProfile.defaults() => const HealthProfile(
        country: CountryCode.brazil,
        primaryCurrency: CurrencyCode.brl,
        interfaceLocale: InterfaceLocale.ptBr,
      );

  factory HealthProfile.fromJson(Map<String, dynamic> json) => HealthProfile(
        country: CountryCode.parse(json['countryCode'] as String),
        primaryCurrency: CurrencyCode.parse(json['primaryCurrency'] as String),
        interfaceLocale: InterfaceLocale.parse(json['localeTag'] as String),
        currencyChangeAllowed: json['currencyChangeAllowed'] as bool? ?? true,
      );

  final CountryCode country;
  final CurrencyCode primaryCurrency;
  final InterfaceLocale interfaceLocale;
  final bool currencyChangeAllowed;

  Map<String, dynamic> toJson() => {
        'countryCode': country.code,
        'primaryCurrency': primaryCurrency.code,
        'localeTag': interfaceLocale.tag,
      };

  HealthProfile copyWith({
    CountryCode? country,
    CurrencyCode? primaryCurrency,
    InterfaceLocale? interfaceLocale,
    bool? currencyChangeAllowed,
  }) =>
      HealthProfile(
        country: country ?? this.country,
        primaryCurrency: primaryCurrency ?? this.primaryCurrency,
        interfaceLocale: interfaceLocale ?? this.interfaceLocale,
        currencyChangeAllowed:
            currencyChangeAllowed ?? this.currencyChangeAllowed,
      );
}
