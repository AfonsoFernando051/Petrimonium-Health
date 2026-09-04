import 'package:flutter_test/flutter_test.dart';
import 'package:petrimonium_health/core/i18n/locale_controller.dart';
import 'package:petrimonium_health/core/profile/health_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'persists and restores pt-PT independently from the device locale',
    () async {
      final first = LocaleController();
      await first.setLocale(InterfaceLocale.ptPt);

      final restored = LocaleController();
      await restored.loadCached();

      expect(restored.current, InterfaceLocale.ptPt);
    },
  );

  test('ignores an invalid cached locale and keeps the safe default', () async {
    SharedPreferences.setMockInitialValues({'health_last_locale': 'en-US'});
    final controller = LocaleController();

    await controller.loadCached();

    expect(controller.current, InterfaceLocale.ptBr);
  });
}
