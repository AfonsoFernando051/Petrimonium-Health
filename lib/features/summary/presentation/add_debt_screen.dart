import 'package:flutter/material.dart';

import '../../../core/app/health_scope.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/health_theme.dart';
import '../../../core/widgets/health_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../health/domain/category_catalog.dart';
import '../../health/presentation/health_controller.dart';

/// `subIsAddDebt`. Debts are planned expenses under a `DebtCategory` — see
/// `HealthController.addDebt`.
class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  DebtCategory _type = DebtCategory.creditCard;
  bool _recurring = true;
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  String _typeLabel(AppLocalizations l10n, DebtCategory type) => switch (type) {
        DebtCategory.creditCard => l10n.debtTypeCreditCard,
        DebtCategory.personalLoan => l10n.debtTypePersonalLoan,
        DebtCategory.carFinancing => l10n.debtTypeCarFinancing,
        DebtCategory.homeFinancing => l10n.debtTypeHomeFinancing,
        DebtCategory.payrollLoan => l10n.debtTypePayrollLoan,
        DebtCategory.other => l10n.debtTypeOther,
      };

  Future<void> _submit(HealthController controller) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final name = _nameController.text.trim();
    final value = MoneyInput.tryParse(_valueController.text, currency: controller.currency, locale: locale);
    if (name.isEmpty || value == null || value.isZero || value.isNegative) return;
    setState(() => _error = null);
    try {
      await controller.addDebt(category: _type, name: name, value: value, recurring: _recurring);
      if (!mounted) return;
      controller.closeSubScreen();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final value = MoneyInput.tryParse(_valueController.text, currency: controller.currency, locale: locale);
    final canSubmit = _nameController.text.trim().isNotEmpty && value != null && !value.isZero && !value.isNegative;

    return Scaffold(
      backgroundColor: HealthColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: controller.closeSubScreen,
                    borderRadius: BorderRadius.circular(16),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.arrow_back, size: 18, color: HealthColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.addDebtTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HealthColors.textPrimary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.debtTypeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HealthColors.textSecondary)),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.6,
                      children: DebtCategory.values.map((type) {
                        final selected = type == _type;
                        return GestureDetector(
                          onTap: () => setState(() => _type = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: .08) : HealthColors.inputFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : HealthColors.border, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(type.icon, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _typeLabel(l10n, type),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      color: selected ? HealthColors.textPrimary : HealthColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 18),
                    Text(l10n.debtRecurringLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HealthColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        HealthChip(label: l10n.yesMonthly, selected: _recurring, onTap: () => setState(() => _recurring = true)),
                        const SizedBox(width: 8),
                        HealthChip(label: l10n.noOneTime, selected: !_recurring, onTap: () => setState(() => _recurring = false)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(hintText: l10n.debtNameHint),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(hintText: _recurring ? l10n.debtValueHintRecurring : l10n.debtValueHintOnce),
                    ),
                    const SizedBox(height: 14),
                    Text(l10n.debtFootnote, style: const TextStyle(fontSize: 11.5, color: HealthColors.textMuted, height: 1.4)),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: HealthColors.negative, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: HealthPrimaryButton(
                label: l10n.addDebtCta,
                busy: controller.busy,
                onPressed: canSubmit ? () => _submit(controller) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
