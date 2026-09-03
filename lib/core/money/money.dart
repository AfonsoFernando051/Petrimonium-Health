enum CurrencyCode {
  brl('BRL'),
  eur('EUR');

  const CurrencyCode(this.code);

  final String code;

  static CurrencyCode parse(String value) => values.firstWhere(
        (currency) => currency.code == value.toUpperCase(),
        orElse: () => throw FormatException('Unsupported currency: $value'),
      );
}

class CurrencyMismatchException implements Exception {
  const CurrencyMismatchException(this.expected, this.actual);

  final CurrencyCode expected;
  final CurrencyCode actual;

  @override
  String toString() =>
      'CurrencyMismatchException(expected: ${expected.code}, actual: ${actual.code})';
}

/// An exact amount represented as integer minor units. BRL and EUR both use
/// two decimal places, so arithmetic never passes through a binary `double`.
final class Money implements Comparable<Money> {
  const Money.fromMinorUnits(this.minorUnits, this.currency);

  factory Money.zero(CurrencyCode currency) => Money.fromMinorUnits(0, currency);

  factory Money.fromDecimal(String decimal, CurrencyCode currency) {
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(decimal.trim());
    if (match == null) throw FormatException('Invalid exact monetary amount: $decimal');

    final sign = match.group(1) == '-' ? -1 : 1;
    final major = int.parse(match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    final minor = fraction.isEmpty ? 0 : int.parse(fraction);
    return Money.fromMinorUnits(sign * (major * 100 + minor), currency);
  }

  final int minorUnits;
  final CurrencyCode currency;

  bool get isNegative => minorUnits < 0;
  bool get isZero => minorUnits == 0;

  String toDecimalString() {
    final absolute = minorUnits.abs();
    final sign = minorUnits < 0 ? '-' : '';
    return '$sign${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  }

  Money operator +(Money other) {
    _ensureSameCurrency(other);
    return Money.fromMinorUnits(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _ensureSameCurrency(other);
    return Money.fromMinorUnits(minorUnits - other.minorUnits, currency);
  }

  Money operator -() => Money.fromMinorUnits(-minorUnits, currency);

  Money abs() => Money.fromMinorUnits(minorUnits.abs(), currency);

  /// Splits an amount without losing cents. Any remainder is assigned one
  /// minor unit at a time to the earliest installments.
  List<Money> splitEvenly(int parts) {
    if (parts <= 0) throw ArgumentError.value(parts, 'parts', 'Must be positive');
    final sign = minorUnits < 0 ? -1 : 1;
    final absolute = minorUnits.abs();
    final quotient = absolute ~/ parts;
    final remainder = absolute % parts;
    return List.generate(
      parts,
      (index) => Money.fromMinorUnits(
        sign * (quotient + (index < remainder ? 1 : 0)),
        currency,
      ),
      growable: false,
    );
  }

  void _ensureSameCurrency(Money other) {
    if (currency != other.currency) {
      throw CurrencyMismatchException(currency, other.currency);
    }
  }

  @override
  int compareTo(Money other) {
    _ensureSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '${currency.code} ${toDecimalString()}';
}
