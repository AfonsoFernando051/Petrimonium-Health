import 'package:flutter/material.dart';

import '../../../core/app/health_scope.dart';
import '../../../core/money/money.dart';
import '../../../core/profile/health_profile.dart';
import '../../../core/theme/health_theme.dart';
import '../../../core/widgets/health_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../health/presentation/health_controller.dart';

class RegionalPreferencesScreen extends StatefulWidget {
  const RegionalPreferencesScreen({super.key});

  @override
  State<RegionalPreferencesScreen> createState() =>
      _RegionalPreferencesScreenState();
}

class _RegionalPreferencesScreenState extends State<RegionalPreferencesScreen> {
  CountryCode _country = CountryCode.brazil;
  CurrencyCode _currency = CurrencyCode.brl;
  InterfaceLocale _locale = InterfaceLocale.ptBr;
  bool _initialized = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final profile = HealthScope.of(context).profile;
    if (profile != null) {
      _country = profile.country;
      _currency = profile.primaryCurrency;
      _locale = profile.interfaceLocale;
    }
    _initialized = true;
  }

  void _selectCountry(CountryCode country, bool currencyChangeAllowed) {
    final suggestion = suggestionFor(country);
    setState(() {
      _country = country;
      if (currencyChangeAllowed) _currency = suggestion.currency;
      _locale = suggestion.locale;
    });
  }

  Future<void> _save() async {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    try {
      await controller.updateProfile(
        HealthProfile(
          country: _country,
          primaryCurrency: _currency,
          interfaceLocale: _locale,
          currencyChangeAllowed:
              controller.profile?.currencyChangeAllowed ?? true,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).preferencesSaved)),
      );
      controller.closeSubScreen();
    } on CurrencyLockedException {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.currencyLockedTitle),
          content: Text(l10n.currencyLockedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);
    final currencyChangeAllowed =
        controller.profile?.currencyChangeAllowed ?? true;

    return Scaffold(
      backgroundColor: HealthColors.background,
      appBar: AppBar(
        backgroundColor: HealthColors.background,
        leading: IconButton(
          onPressed: controller.openProfile,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(l10n.preferences),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _SectionLabel(l10n.country),
            const SizedBox(height: 8),
            Row(
              children: [
                HealthChip(
                  label: l10n.countryBrazil,
                  selected: _country == CountryCode.brazil,
                  onTap: () =>
                      _selectCountry(CountryCode.brazil, currencyChangeAllowed),
                ),
                const SizedBox(width: 8),
                HealthChip(
                  label: l10n.countryPortugal,
                  selected: _country == CountryCode.portugal,
                  onTap: () => _selectCountry(
                    CountryCode.portugal,
                    currencyChangeAllowed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionLabel(l10n.primaryCurrency),
            const SizedBox(height: 8),
            Row(
              children: [
                HealthChip(
                  label: l10n.currencyBrl,
                  selected: _currency == CurrencyCode.brl,
                  enabled: currencyChangeAllowed,
                  onTap: () => setState(() => _currency = CurrencyCode.brl),
                ),
                const SizedBox(width: 8),
                HealthChip(
                  label: l10n.currencyEur,
                  selected: _currency == CurrencyCode.eur,
                  enabled: currencyChangeAllowed,
                  onTap: () => setState(() => _currency = CurrencyCode.eur),
                ),
              ],
            ),
            if (!currencyChangeAllowed) ...[
              const SizedBox(height: 10),
              Text(
                l10n.currencyLockedBody,
                style: const TextStyle(
                  color: HealthColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 22),
            _SectionLabel(l10n.interfaceLanguage),
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
            const SizedBox(height: 12),
            Text(
              l10n.countrySuggestion,
              style: const TextStyle(
                color: HealthColors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(color: HealthColors.negative),
              ),
            ],
            const SizedBox(height: 28),
            HealthPrimaryButton(
              label: l10n.save,
              busy: controller.busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: HealthColors.textSecondary,
    ),
  );
}
