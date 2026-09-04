import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'money.dart';

abstract final class MoneyFormat {
  static String currency(Money money, Locale locale) {
    final formatter = NumberFormat.currency(
      locale: locale.toLanguageTag(),
      name: money.currency.code,
      symbol: switch (money.currency) {
        CurrencyCode.brl => 'R\$',
        CurrencyCode.eur => '€',
      },
      decimalDigits: 2,
    );
    return formatter.format(money.minorUnits / 100);
  }

  static String number(num value, Locale locale, {int decimalDigits = 2}) {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: locale.toLanguageTag(),
      decimalDigits: decimalDigits,
    );
    return formatter.format(value);
  }

  static String date(DateTime value, Locale locale) =>
      DateFormat.yMd(locale.toLanguageTag()).format(value);

  static String monthYear(DateTime value, Locale locale) =>
      DateFormat.yMMMM(locale.toLanguageTag()).format(value);
}

abstract final class MoneyInput {
  /// Parses localized Portuguese input into exact minor units. Both supported
  /// locales use comma decimals; a dot decimal is accepted for pasted API-like
  /// values. More than two fractional digits are rejected, never rounded.
  static Money? tryParse(
    String raw, {
    required CurrencyCode currency,
    required Locale locale,
  }) {
    var value = raw
        .trim()
        .replaceAll(RegExp(r'\s|\u00a0|\u202f'), '')
        .replaceAll('R\$', '')
        .replaceAll('€', '')
        .replaceAll(currency.code, '')
        .trim();
    if (value.isEmpty) return null;

    if (value.contains(',')) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else {
      final dots = '.'.allMatches(value).length;
      if (dots > 1) {
        value = value.replaceAll('.', '');
      } else if (dots == 1) {
        final fractionLength = value.length - value.lastIndexOf('.') - 1;
        if (fractionLength == 3 && locale.languageCode == 'pt') {
          value = value.replaceAll('.', '');
        }
      }
    }

    try {
      return Money.fromDecimal(value, currency);
    } on FormatException {
      return null;
    }
  }
}
