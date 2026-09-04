import 'package:flutter/material.dart';

import '../../../core/app/health_scope.dart';
import '../../../core/money/money.dart';
import '../../../core/profile/health_profile.dart';
import '../../../core/theme/health_theme.dart';
import '../../../core/widgets/health_widgets.dart';
import '../../../l10n/app_localizations.dart';

/// `screenIsQuickSetup` — país/moeda/idioma are persisted independently.
/// Changing the country applies the regional suggestion, but the user can
/// override currency and language before saving.
class QuickSetupScreen extends StatefulWidget {
  const QuickSetupScreen({super.key});

  @override
  State<QuickSetupScreen> createState() => _QuickSetupScreenState();
}

class _QuickSetupScreenState extends State<QuickSetupScreen> {
  CountryCode _country = CountryCode.brazil;
  CurrencyCode _currency = CurrencyCode.brl;
  InterfaceLocale _locale = InterfaceLocale.ptBr;
  String? _error;

  void _selectCountry(CountryCode country) {
    final suggestion = suggestionFor(country);
    setState(() {
      _country = country;
      _currency = suggestion.currency;
      _locale = suggestion.locale;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final controller = HealthScope.of(context);
    setState(() => _error = null);
    final profile = HealthProfile(
      country: _country,
      primaryCurrency: _currency,
      interfaceLocale: _locale,
    );
    try {
      await controller.saveOnboarding(profile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.onboardingSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: HealthColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    l10n.quickSetupTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: HealthColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.quickSetupSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: HealthColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.country,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: HealthColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        HealthChip(
                          label: l10n.countryBrazil,
                          selected: _country == CountryCode.brazil,
                          expanded: false,
                          onTap: () => _selectCountry(CountryCode.brazil),
                        ),
                        HealthChip(
                          label: l10n.countryPortugal,
                          selected: _country == CountryCode.portugal,
                          expanded: false,
                          onTap: () => _selectCountry(CountryCode.portugal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.primaryCurrency,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: HealthColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        HealthChip(
                          label: l10n.currencyBrl,
                          selected: _currency == CurrencyCode.brl,
                          expanded: false,
                          onTap: () =>
                              setState(() => _currency = CurrencyCode.brl),
                        ),
                        HealthChip(
                          label: l10n.currencyEur,
                          selected: _currency == CurrencyCode.eur,
                          expanded: false,
                          onTap: () =>
                              setState(() => _currency = CurrencyCode.eur),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.countrySuggestion,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: HealthColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.interfaceLanguage,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: HealthColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        HealthChip(
                          label: l10n.languagePtBr,
                          selected: _locale == InterfaceLocale.ptBr,
                          expanded: false,
                          onTap: () =>
                              setState(() => _locale = InterfaceLocale.ptBr),
                        ),
                        HealthChip(
                          label: l10n.languagePtPt,
                          selected: _locale == InterfaceLocale.ptPt,
                          expanded: false,
                          onTap: () =>
                              setState(() => _locale = InterfaceLocale.ptPt),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: HealthColors.inputFill,
                        border: Border.all(color: HealthColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.singleCurrencyNotice,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HealthColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: HealthColors.negative,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  ProgressDots(
                    total: controller.onboardingTotalSteps,
                    current: controller.onboardingTotalSteps,
                  ),
                  const SizedBox(height: 16),
                  HealthPrimaryButton(
                    label: l10n.quickSetupCta,
                    busy: controller.busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
