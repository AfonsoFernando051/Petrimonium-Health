import 'package:flutter/material.dart';

import '../../../core/app/health_scope.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/health_theme.dart';
import '../../../core/widgets/health_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../health/domain/category_catalog.dart';
import '../../health/domain/health_models.dart';
import '../../health/presentation/health_controller.dart';

/// `tabIsHome` — the Health dashboard. Every figure comes straight from
/// `GET /api/v1/health/summary`; debts and income sources are derived from
/// planned transactions/recurrences (see `HealthController`'s doc comment).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final summary = controller.summary;

    if (summary == null) {
      if (controller.error == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: HealthColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.genericError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: HealthColors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.busy || controller.refreshing
                    ? null
                    : controller.refreshData,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.accounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 44,
                color: HealthColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.emptySummary,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HealthColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: controller.openAccounts,
                icon: const Icon(Icons.add),
                label: Text(l10n.addAccount),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refreshData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _Greeting(controller: controller, l10n: l10n),
          const SizedBox(height: 16),
          if (!controller.insightDismissed) ...[
            _MentorInsightCard(
              controller: controller,
              l10n: l10n,
              locale: locale,
              summary: summary,
            ),
            const SizedBox(height: 16),
          ],
          _StatGrid(summary: summary, l10n: l10n, locale: locale),
          const SizedBox(height: 16),
          _UpcomingCard(summary: summary, l10n: l10n),
          const SizedBox(height: 16),
          _IncomeCard(controller: controller, l10n: l10n, locale: locale),
          const SizedBox(height: 16),
          _DebtsCard(controller: controller, l10n: l10n, locale: locale),
          const SizedBox(height: 16),
          _CategoryExpensesCard(summary: summary, l10n: l10n, locale: locale),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.controller, required this.l10n});

  final HealthController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final name = controller.account?.username;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.greetingBack,
          style: const TextStyle(
            fontSize: 13,
            color: HealthColors.textSecondary,
          ),
        ),
        if (name != null && name.isNotEmpty)
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: HealthColors.textPrimary,
            ),
          ),
      ],
    );
  }
}

class _MentorInsightCard extends StatelessWidget {
  const _MentorInsightCard({
    required this.controller,
    required this.l10n,
    required this.locale,
    required this.summary,
  });

  final HealthController controller;
  final AppLocalizations l10n;
  final Locale locale;
  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final amount = MoneyFormat.currency(summary.projectedEndBalance, locale);
    final date = MoneyFormat.date(
      DateTime(summary.month.year, summary.month.month + 1, 0),
      locale,
    );
    final text = summary.monthResult.isNegative
        ? l10n.mentorInsightNegative(amount, date)
        : l10n.mentorInsightPositive(amount, date);

    return HealthPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/pets/fox.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.mentorLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HealthColors.textSecondary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: controller.dismissInsight,
                child: const Text(
                  '×',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFFB7B0A5),
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: HealthColors.textPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => controller.selectTab(AppTab.mentor),
            child: Text(
              l10n.mentorInsightWhy,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.summary,
    required this.l10n,
    required this.locale,
  });

  final MonthlySummary summary;
  final AppLocalizations l10n;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final monthEnd = DateTime(summary.month.year, summary.month.month + 1, 0);
    final commitments = summary.plannedExpenses + summary.openCardInvoices;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _StatTile(
          label: l10n.currentBalance,
          value: summary.currentBalance,
          sub: l10n.allAccountsToday,
          locale: locale,
        ),
        _StatTile(
          label: l10n.monthResult,
          value: summary.monthResult,
          sub: l10n.monthResultSubtitle,
          locale: locale,
          valueColor: summary.monthResult.isNegative
              ? HealthColors.negative
              : HealthColors.positive,
        ),
        _StatTile(
          label: l10n.expectedCommitments,
          value: commitments,
          sub: l10n.commitmentsSubtitle,
          locale: locale,
        ),
        _StatTile(
          label: l10n.projectedBalance,
          value: summary.projectedEndBalance,
          sub: l10n.projectedUntil(MoneyFormat.date(monthEnd, locale)),
          locale: locale,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.locale,
    this.valueColor = HealthColors.textPrimary,
  });

  final String label;
  final Money value;
  final String sub;
  final Locale locale;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HealthColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HealthColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: HealthColors.textMuted,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              MoneyFormat.currency(value, locale),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: HealthColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.summary, required this.l10n});

  final MonthlySummary summary;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return HealthPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.upcomingCommitments,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HealthColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (summary.upcoming.isEmpty)
            Text(
              l10n.noUpcoming,
              style: const TextStyle(
                fontSize: 12.5,
                color: HealthColors.textMuted,
              ),
            )
          else
            ...summary.upcoming.map(
              (u) => _IconRow(
                icon: '💳',
                name: u.description,
                subtitle: l10n.dueOn(
                  MoneyFormat.date(u.date, Localizations.localeOf(context)),
                ),
                value: u.amount,
                locale: Localizations.localeOf(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({
    required this.controller,
    required this.l10n,
    required this.locale,
  });

  final HealthController controller;
  final AppLocalizations l10n;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      ...controller.incomeRecurrences.map(
        (r) => _IconRow(
          icon:
              (IncomeCategory.fromApiCategory(r.category) ??
                      IncomeCategory.other)
                  .icon,
          name: r.description,
          subtitle: l10n.recurringLabelIncomeMonthly,
          value: r.amount,
          locale: locale,
          valueColor: HealthColors.positive,
        ),
      ),
      ...controller.oneOffIncomes.map(
        (t) => _IconRow(
          icon:
              (IncomeCategory.fromApiCategory(t.category) ??
                      IncomeCategory.other)
                  .icon,
          name: t.description,
          subtitle: l10n.recurringLabelIncomeOnce,
          value: t.amount,
          locale: locale,
          valueColor: HealthColors.positive,
        ),
      ),
    ];

    return HealthPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.incomeSectionTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HealthColors.textPrimary,
                  ),
                ),
              ),
              _AddLink(label: l10n.addLabel, onTap: controller.openAddIncome),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.incomeSectionSubtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: HealthColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              l10n.noUpcoming,
              style: const TextStyle(
                fontSize: 12.5,
                color: HealthColors.textMuted,
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

class _DebtsCard extends StatelessWidget {
  const _DebtsCard({
    required this.controller,
    required this.l10n,
    required this.locale,
  });

  final HealthController controller;
  final AppLocalizations l10n;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      ...controller.debtRecurrences.map(
        (r) => _IconRow(
          icon: (DebtCategory.fromApiCategory(r.category) ?? DebtCategory.other)
              .icon,
          name: r.description,
          subtitle: l10n.recurringLabelMonthly,
          value: r.amount,
          locale: locale,
        ),
      ),
      ...controller.oneOffDebts.map(
        (t) => _IconRow(
          icon: (DebtCategory.fromApiCategory(t.category) ?? DebtCategory.other)
              .icon,
          name: t.description,
          subtitle: l10n.recurringLabelOneTime,
          value: t.amount,
          locale: locale,
        ),
      ),
    ];

    return HealthPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.debtsSectionTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HealthColors.textPrimary,
                  ),
                ),
              ),
              _AddLink(label: l10n.addLabel, onTap: controller.openAddDebt),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.debtsSectionSubtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: HealthColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              l10n.noDebts,
              style: const TextStyle(
                fontSize: 12.5,
                color: HealthColors.textMuted,
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

class _CategoryExpensesCard extends StatelessWidget {
  const _CategoryExpensesCard({
    required this.summary,
    required this.l10n,
    required this.locale,
  });

  final MonthlySummary summary;
  final AppLocalizations l10n;
  final Locale locale;

  static const _palette = [
    HealthAccent.terracotta,
    HealthColors.positive,
    HealthColors.mentorAccent,
    HealthAccent.ochre,
    HealthColors.textMuted,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = summary.expensesByCategory;
    final total = entries.fold<int>(0, (sum, e) => sum + e.amount.minorUnits);
    final monthLabel = MoneyFormat.monthYear(summary.month, locale);

    return HealthPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.categorySectionTitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HealthColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.categorySectionSubtitle(monthLabel),
            style: const TextStyle(
              fontSize: 10.5,
              color: HealthColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              l10n.noTransactions,
              style: const TextStyle(
                fontSize: 12.5,
                color: HealthColors.textMuted,
              ),
            )
          else
            ...entries.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              final pct = total == 0
                  ? 0
                  : (category.amount.minorUnits / total * 100).round();
              final color = _palette[index % _palette.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category.category,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: HealthColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${MoneyFormat.currency(category.amount, locale)} · $pct%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: HealthColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 7,
                        backgroundColor: HealthColors.background,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AddLink extends StatelessWidget {
  const _AddLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('+', style: TextStyle(fontSize: 15, height: 1, color: accent)),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.value,
    required this.locale,
    this.valueColor = HealthColors.textPrimary,
  });

  final String icon;
  final String name;
  final String subtitle;
  final Money value;
  final Locale locale;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HealthColors.inputFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HealthColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: HealthColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            MoneyFormat.currency(value, locale),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
