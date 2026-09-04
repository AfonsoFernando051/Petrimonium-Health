import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petrimonium_health/core/network/api_client.dart';

void main() {
  test('a keyring that never answers reads as "no stored session"', () async {
    final store = SecureTokenStore(
      storage: _HangingStorage(),
      readTimeout: const Duration(milliseconds: 50),
    );

    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
  });

  test('a keyring that answers is read normally', () async {
    final store = SecureTokenStore(
      storage: _StubStorage({'health_access_token': 'abc'}),
      readTimeout: const Duration(seconds: 5),
    );

    expect(await store.readAccessToken(), 'abc');
    expect(await store.readRefreshToken(), isNull);
  });

  test('ApiClient reports no session when the keyring hangs', () async {
    final api = ApiClient(
      tokenStore: SecureTokenStore(
        storage: _HangingStorage(),
        readTimeout: const Duration(milliseconds: 50),
      ),
    );

    // Must resolve rather than hang: this is the call the splash screen is
    // waiting on before it can route to the login screen.
    expect(await api.hasSession(), isFalse);
  });
}

/// A keyring blocked on an unlock prompt nobody can answer.
class _HangingStorage implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => Completer<String?>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubStorage implements FlutterSecureStorage {
  _StubStorage(this._values);

  final Map<String, String> _values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
