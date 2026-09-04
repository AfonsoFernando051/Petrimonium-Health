import 'package:flutter/material.dart';

import '../../../core/app/health_scope.dart';
import '../../../core/profile/health_profile.dart';
import '../../../core/theme/health_theme.dart';
import '../../../core/widgets/health_widgets.dart';
import '../../../l10n/app_localizations.dart';

/// `screenIsQuickSetup` — país/moeda/idioma. Currency is never chosen
/// directly; it is derived from the country, per the ecosystem PRD
/// (`docs/API.md`: "os campos são independentes... o servidor não troca
/// moeda ou idioma por inferência"). The design still shows currency, but as
/// a read-only outcome of the country choice, and the confirmation card
/// leaves the currency detail out entirely (per the design chat history).
class QuickSetupScreen extends StatefulWidget {
  const QuickSetupScreen({super.key});

  @override
  State<QuickSetupScreen> createState() => _QuickSetupScreenState();
}

class _QuickSetupScreenState extends State<QuickSetupScreen> {
  CountryCode _country = CountryCode.brazil;
  InterfaceLocale _locale = InterfaceLocale.ptBr;
  String? _error;

  void _selectCountry(CountryCode country) {
    final suggestion = suggestionFor(country);
    setState(() {
      _country = country;
      _locale = suggestion.locale;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final controller = HealthScope.of(context);
    setState(() => _error = null);
    final profile = HealthProfile(
      country: _country,
      primaryCurrency: suggestionFor(_country).currency,
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
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: HealthColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.quickSetupSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, color: HealthColors.textSecondary, height: 1.4),
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
                    Text(l10n.country, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: HealthColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        HealthChip(
                          label: l10n.countryBrazil,
                          selected: _country == CountryCode.brazil,
                          onTap: () => _selectCountry(CountryCode.brazil),
                        ),
                        const SizedBox(width: 8),
                        HealthChip(
                          label: l10n.countryPortugal,
                          selected: _country == CountryCode.portugal,
                          onTap: () => _selectCountry(CountryCode.portugal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.interfaceLanguage, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: HealthColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        HealthChip(
                          label: l10n.languagePtBr,
                          selected: _locale == InterfaceLocale.ptBr,
                          onTap: () => setState(() => _locale = InterfaceLocale.ptBr),
                        ),
                        const SizedBox(width: 8),
                        HealthChip(
                          label: l10n.languagePtPt,
                          selected: _locale == InterfaceLocale.ptPt,
                          onTap: () => setState(() => _locale = InterfaceLocale.ptPt),
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
                        style: const TextStyle(fontSize: 12, color: HealthColors.textMuted, height: 1.4),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: HealthColors.negative, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  ProgressDots(total: controller.onboardingTotalSteps, current: controller.onboardingTotalSteps),
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
