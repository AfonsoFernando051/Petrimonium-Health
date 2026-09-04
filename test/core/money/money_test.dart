import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petrimonium_health/core/money/money.dart';
import 'package:petrimonium_health/core/money/money_format.dart';

void main() {
  group('Money', () {
    test('keeps BRL and EUR amounts in exact minor units', () {
      final brl = Money.fromDecimal('1234.56', CurrencyCode.brl);
      final eur = Money.fromDecimal('1234.56', CurrencyCode.eur);

      expect(brl.minorUnits, 123456);
      expect(eur.minorUnits, 123456);
      expect(brl.toDecimalString(), '1234.56');
      expect(eur.toDecimalString(), '1234.56');
      expect(brl, isNot(eur));
    });

    test('rejects excess precision instead of rounding it', () {
      expect(
        () => Money.fromDecimal('10.001', CurrencyCode.eur),
        throwsFormatException,
      );
    });

    test('never adds different currencies', () {
      final brl = Money.fromDecimal('10.00', CurrencyCode.brl);
      final eur = Money.fromDecimal('10.00', CurrencyCode.eur);

      expect(() => brl + eur, throwsA(isA<CurrencyMismatchException>()));
      expect(
        () => brl.compareTo(eur),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('installments add back to the original amount exactly', () {
      final total = Money.fromDecimal('1000.00', CurrencyCode.eur);
      final installments = total.splitEvenly(3);

      expect(installments.map((item) => item.minorUnits), [
        33334,
        33333,
        33333,
      ]);
      expect(
        installments.fold(
          Money.zero(CurrencyCode.eur),
          (sum, item) => sum + item,
        ),
        total,
      );
    });
  });

  group('localized money input and output', () {
    String normalized(String value) =>
        value.replaceAll('\u00a0', ' ').replaceAll('\u202f', ' ');

    test('parses Brazilian and Portuguese manual input without doubles', () {
      expect(
        MoneyInput.tryParse(
          'R\$ 1.234,56',
          currency: CurrencyCode.brl,
          locale: const Locale('pt', 'BR'),
        ),
        Money.fromDecimal('1234.56', CurrencyCode.brl),
      );
      expect(
        MoneyInput.tryParse(
          '1 234,56 €',
          currency: CurrencyCode.eur,
          locale: const Locale('pt', 'PT'),
        ),
        Money.fromDecimal('1234.56', CurrencyCode.eur),
      );
    });

    test('formats BRL and EUR with the selected locale', () {
      final brl = normalized(
        MoneyFormat.currency(
          Money.fromDecimal('1234.56', CurrencyCode.brl),
          const Locale('pt', 'BR'),
        ),
      );
      final eur = normalized(
        MoneyFormat.currency(
          Money.fromDecimal('1234.56', CurrencyCode.eur),
          const Locale('pt', 'PT'),
        ),
      );

      expect(brl, contains('R\$'));
      expect(brl, contains('1.234,56'));
      expect(eur, contains('€'));
      expect(eur, contains('1 234,56'));
    });
  });
}
