import 'package:flutter/material.dart';

import '../../features/health/presentation/health_controller.dart';
import '../../features/mentor/presentation/mentor_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/regional_preferences_screen.dart';
import '../../features/summary/presentation/add_debt_screen.dart';
import '../../features/summary/presentation/add_income_screen.dart';
import '../../features/summary/presentation/home_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../../features/accounts/presentation/accounts_cards_screen.dart';
import '../../l10n/app_localizations.dart';
import '../money/money_format.dart';
import '../theme/health_theme.dart';
import 'health_scope.dart';

/// Everything under `screenIsApp`: the top bar, the four primary sections,
/// and the stacked profile/onboarding helper screens.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    switch (controller.subScreen) {
      case AppSubScreen.profile:
        return const ProfileScreen();
      case AppSubScreen.regionalPreferences:
        return const RegionalPreferencesScreen();
      case AppSubScreen.addDebt:
        return const AddDebtScreen();
      case AppSubScreen.addIncome:
        return const AddIncomeScreen();
      case AppSubScreen.root:
        return const _MainScaffold();
    }
  }
}

class _MainScaffold extends StatelessWidget {
  const _MainScaffold();

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    return Scaffold(
      backgroundColor: HealthColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(controller: controller),
            Expanded(
              child: switch (controller.tab) {
                AppTab.home => const HomeScreen(),
                AppTab.transactions => const TransactionsScreen(),
                AppTab.accounts => const AccountsCardsScreen(),
                AppTab.mentor => const MentorScreen(),
              },
            ),
            _BottomNav(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final HealthController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasUpcoming = (controller.summary?.upcoming ?? const []).isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Image.asset(
                    'assets/pets/fox.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PETRIMONIUM HEALTH',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: controller.toggleNotif,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        size: 20,
                        color: HealthColors.textSecondary,
                      ),
                      if (hasUpcoming)
                        Positioned(
                          top: 5,
                          right: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: HealthColors.negative,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(
                                  color: HealthColors.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: controller.openProfile,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: HealthColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (controller.notifOpen)
          Positioned(
            top: 44,
            right: 16,
            child: _NotificationsPanel(controller: controller, l10n: l10n),
          ),
      ],
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel({required this.controller, required this.l10n});

  final HealthController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final upcoming = controller.summary?.upcoming ?? const [];
    final locale = Localizations.localeOf(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HealthColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E3C3228),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.notificationsTitle.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: HealthColors.textMuted,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 10),
            if (upcoming.isEmpty)
              Text(
                l10n.noUpcoming,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: HealthColors.textMuted,
                ),
              )
            else
              ...upcoming.map(
                (u) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.description,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: HealthColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              l10n.dueOn(
                                MaterialLocalizations.of(
                                  context,
                                ).formatShortDate(u.date),
                              ),
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: HealthColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        MoneyFormat.currency(u.amount, locale),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: HealthColors.negative,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.controller});

  final HealthController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: HealthColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: l10n.homeTab,
            active: controller.tab == AppTab.home,
            accent: accent,
            onTap: () => controller.selectTab(AppTab.home),
          ),
          _NavItem(
            icon: Icons.receipt_long_rounded,
            label: l10n.transactionsTab,
            active: controller.tab == AppTab.transactions,
            accent: accent,
            onTap: () => controller.selectTab(AppTab.transactions),
          ),
          _NavItem(
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.accountsTab,
            active: controller.tab == AppTab.accounts,
            accent: accent,
            onTap: () => controller.selectTab(AppTab.accounts),
          ),
          _NavItem(
            icon: Icons.auto_awesome_rounded,
            label: l10n.mentorTab,
            active: controller.tab == AppTab.mentor,
            accent: accent,
            onTap: () => controller.selectTab(AppTab.mentor),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : HealthColors.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
