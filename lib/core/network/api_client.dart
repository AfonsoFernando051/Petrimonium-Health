import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens(String accessToken, String refreshToken);
  Future<void> clear();
}

final class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage, Duration? readTimeout})
      : _storage = storage ?? const FlutterSecureStorage(),
        _readTimeout = readTimeout ?? const Duration(seconds: 5);

  static const _accessKey = 'health_access_token';
  static const _refreshKey = 'health_refresh_token';
  final FlutterSecureStorage _storage;
  final Duration _readTimeout;

  /// Startup can't decide which screen to show until it knows whether a token
  /// exists, so this read sits between the splash and everything else.
  ///
  /// It goes through the platform keyring, which does not always answer: a
  /// locked GNOME keyring raises an unlock prompt and blocks until someone
  /// answers it, and with no session to show that prompt in, the read simply
  /// never completes. That is not an exception, so no `try`/`catch` upstream
  /// can recover from it — the app just sits on the spinner forever.
  ///
  /// Time it out and report "no stored token" instead. The worst case is a
  /// user with a valid session landing on the login screen, which they can
  /// act on; the alternative is a splash screen they cannot leave.
  Future<String?> _read(String key) =>
      _storage.read(key: key).timeout(_readTimeout, onTimeout: () => null);

  @override
  Future<String?> readAccessToken() => _read(_accessKey);

  @override
  Future<String?> readRefreshToken() => _read(_refreshKey);

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

final class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
  });

  final int statusCode;
  final String message;
  final String? code;

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

final class ApiClient {
  ApiClient({
    http.Client? httpClient,
    TokenStore? tokenStore,
    String? baseUrl,
  })  : _http = httpClient ?? http.Client(),
        tokenStore = tokenStore ?? SecureTokenStore(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _http;
  final TokenStore tokenStore;
  final String baseUrl;
  static const _timeout = Duration(seconds: 15);
  Future<bool>? _refreshInFlight;

  Future<bool> hasSession() async =>
      (await tokenStore.readAccessToken())?.isNotEmpty ?? false;

  Future<http.Response> get(String path) => _send('GET', path);
  Future<http.Response> post(String path, Object? body) =>
      _send('POST', path, body: body);
  Future<http.Response> put(String path, Object? body) =>
      _send('PUT', path, body: body);
  Future<http.Response> delete(String path) => _send('DELETE', path);

  Future<http.Response> unauthenticatedPost(String path, Object? body) =>
      _send('POST', path, body: body, authenticated: false);

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
    bool retrying = false,
  }) async {
    final token = authenticated ? await tokenStore.readAccessToken() : null;
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    // The budget has to cover reading the body too, not just the response
    // headers — a server that answers and then stalls mid-body would
    // otherwise hang the caller indefinitely.
    final response = await _http
        .send(request)
        .then(http.Response.fromStream)
        .timeout(_timeout);
    if (authenticated && response.statusCode == 401 && !retrying) {
      final refreshed = await _refresh();
      if (refreshed) {
        return _send(method, path, body: body, retrying: true);
      }
    }
    return response;
  }

  Future<bool> _refresh() => _refreshInFlight ??=
      _performRefresh().whenComplete(() => _refreshInFlight = null);

  Future<bool> _performRefresh() async {
    final refreshToken = await tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await tokenStore.clear();
      return false;
    }
    try {
      final response = await unauthenticatedPost(
        '/auth/refresh',
        {'refreshToken': refreshToken},
      );
      if (response.statusCode != 200) {
        await tokenStore.clear();
        return false;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      await tokenStore.saveTokens(
        json['accessToken'] as String,
        json['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

Map<String, dynamic> decodeObject(http.Response response) {
  if (response.body.isEmpty) return <String, dynamic>{};
  return jsonDecode(response.body) as Map<String, dynamic>;
}

List<Map<String, dynamic>> decodeList(http.Response response) {
  if (response.body.isEmpty) return const [];
  return (jsonDecode(response.body) as List)
      .cast<Map<String, dynamic>>();
}

Never throwApiError(http.Response response) {
  String message = 'HTTP ${response.statusCode}';
  String? code;
  try {
    final body = decodeObject(response);
    message = (body['detail'] ?? body['message'] ?? body['title'] ?? message)
        .toString();
    code = body['code'] as String?;
  } catch (_) {
    if (response.body.isNotEmpty) message = response.body;
  }
  throw ApiException(
    statusCode: response.statusCode,
    message: message,
    code: code,
  );
}
