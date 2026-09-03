import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8081',
  );

  static const String appContext = 'health';
  static const String healthBase = '/api/v1/health';

  static void assertConfiguredForRelease() {
    if (kReleaseMode && baseUrl == 'http://localhost:8081') {
      throw StateError(
        'API_BASE_URL precisa ser definido em builds de produção.',
      );
    }
  }
}
