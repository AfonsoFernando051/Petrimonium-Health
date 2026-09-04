import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app/app_shell.dart';
import 'core/app/health_scope.dart';
import 'core/config/api_config.dart';
import 'core/i18n/locale_controller.dart';
import 'core/network/api_client.dart';
import 'core/theme/health_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/health/data/remote_health_repository.dart';
import 'features/health/presentation/health_controller.dart';
import 'features/onboarding/presentation/pet_setup_screen.dart';
import 'features/onboarding/presentation/quick_setup_screen.dart';
import 'l10n/app_localizations.dart';

void main() {
  ApiConfig.assertConfiguredForRelease();
  runApp(const PetrimoniumHealthApp());
}

class PetrimoniumHealthApp extends StatefulWidget {
  const PetrimoniumHealthApp({super.key});

  @override
  State<PetrimoniumHealthApp> createState() => _PetrimoniumHealthAppState();
}

class _PetrimoniumHealthAppState extends State<PetrimoniumHealthApp> {
  late final LocaleController _localeController;
  late final HealthController _controller;
  late final Listenable _appListenable;

  @override
  void initState() {
    super.initState();
    _localeController = LocaleController();
    final repository = RemoteHealthRepository(ApiClient());
    _controller = HealthController(repository: repository, localeController: _localeController);
    _appListenable = Listenable.merge([_controller, _localeController]);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _localeController.loadCached();
    await _controller.restore();
  }

  @override
  void dispose() {
    _controller.dispose();
    _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appListenable,
      builder: (context, _) {
        return MaterialApp(
          title: 'Petrimonium Health',
          debugShowCheckedModeBanner: false,
          theme: buildHealthTheme(),
          locale: _localeController.current.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HealthScope(controller: _controller, child: const _RootRouter()),
        );
      },
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    switch (controller.stage) {
      case AppStage.loading:
        return const Scaffold(
          backgroundColor: HealthColors.background,
          body: Center(child: CircularProgressIndicator()),
        );
      case AppStage.signedOut:
        return const LoginScreen();
      case AppStage.onboarding:
        return controller.onboardingStep == OnboardingStep.petSetup
            ? const PetSetupScreen()
            : const QuickSetupScreen();
      case AppStage.home:
        return const AppShell();
    }
  }
}
