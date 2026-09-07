import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:petrimonium_health/core/money/money.dart';
import 'package:petrimonium_health/core/network/api_client.dart';
import 'package:petrimonium_health/features/health/data/remote_health_repository.dart';
import 'package:petrimonium_health/features/health/domain/health_models.dart';

/// Every create sends an idempotency key, and generating it must not throw.
///
/// Run these on Chrome too (`flutter test --platform chrome`): the bound used
/// to be `1 << 32`, which is `0` on the web because dart2js shifts are 32-bit,
/// so `Random.nextInt` threw `RangeError` and no account, entry, transfer or
/// card could be created in a web build at all -- while the same code worked
/// on mobile, where the shift is 64-bit.
void main() {
  late List<Map<String, dynamic>> bodies;
  late RemoteHealthRepository repository;

  Map<String, dynamic> accountJson() => {
        'id': 1,
        'name': 'Conta à ordem',
        'type': 'CHECKING',
        'initialBalance': '850.00',
        'balanceReferenceDate': '2026-09-01',
        'currentBalance': '850.00',
        'currency': 'EUR',
        'archived': false,
      };

  setUp(() {
    bodies = [];
    repository = RemoteHealthRepository(ApiClient(
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode(accountJson()), 201,
            headers: {'content-type': 'application/json'});
      }),
      tokenStore: _NoSession(),
      baseUrl: 'http://localhost:8081',
    ));
  });

  Future<void> createAccount() => repository.createAccount(
        name: 'Conta à ordem',
        type: AccountType.checking,
        initialBalance: Money.fromDecimal('850.00', CurrencyCode.eur),
        balanceReferenceDate: DateTime(2026, 9, 1),
      );

  test('creating an account sends a usable idempotency key', () async {
    await createAccount();

    final key = bodies.single['idempotencyKey'] as String;
    expect(key, isNotEmpty);
    expect(key.length, lessThanOrEqualTo(64),
        reason: 'the backend caps the key at 64 characters');
  });

  test('two creates never reuse the same key', () async {
    await createAccount();
    await createAccount();

    expect(bodies[0]['idempotencyKey'], isNot(bodies[1]['idempotencyKey']),
        reason: 'a reused key makes the second create silently return the first');
  });

  test('a transfer carries its own key so a retry cannot move money twice', () async {
    await repository.createTransfer(
      fromAccountId: 1,
      toAccountId: 2,
      amount: Money.fromDecimal('100.00', CurrencyCode.eur),
      date: DateTime(2026, 9, 3),
      description: 'Reserva',
    );

    expect(bodies.single['idempotencyKey'], isNotEmpty);
  });
}

final class _NoSession implements TokenStore {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {}

  @override
  Future<void> clear() async {}
}
