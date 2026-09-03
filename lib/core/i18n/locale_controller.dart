import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profile/health_profile.dart';

final class LocaleController extends ChangeNotifier {
  LocaleController({InterfaceLocale initial = InterfaceLocale.ptBr})
      : _current = initial;

  static const _cacheKey = 'health_last_locale';
  InterfaceLocale _current;

  InterfaceLocale get current => _current;

  Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      _current = InterfaceLocale.parse(raw);
    } on FormatException {
      return;
    }
  }

  Future<void> setLocale(InterfaceLocale locale) async {
    if (_current == locale) return;
    _current = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, locale.tag);
  }
}
