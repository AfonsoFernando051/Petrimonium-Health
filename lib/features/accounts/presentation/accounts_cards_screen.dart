import 'package:flutter/material.dart';

import '../../../core/app/health_scope.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/health_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../health/domain/health_models.dart';
import '../../health/presentation/health_controller.dart';

/// `AppTab.accounts` — manual account and card management. Not part of the
/// design prototype (which never surfaces account selection at all), but
/// needed once transactions/cards became their own tab: someone has to be
/// able to create the accounts and cards those screens assume exist.
/// Styled like `TransactionsScreen` (plain Material), not the DC-fidelity
/// screens — this whole feature has no prototype to match.
class AccountsCardsScreen extends StatelessWidget {
  const AccountsCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: controller.refreshData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.accountsTab,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: HealthColors.textPrimary,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _editAccount(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addAccount),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (controller.accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l10n.noAccounts),
            )
          else
            ...controller.accounts.map(
              (account) => _AccountTile(account: account),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.cardsTab,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: HealthColors.textPrimary,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _editCard(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addCard),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (controller.cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l10n.noCards),
            )
          else
            ...controller.cards.map((card) => _CardTile(card: card)),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final HealthAccount account;

  String _typeLabel(AppLocalizations l10n) => switch (account.type) {
        AccountType.checking => l10n.accountChecking,
        AccountType.savings => l10n.accountSavings,
        AccountType.cash => l10n.accountCash,
        AccountType.other => l10n.accountOther,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.account_balance_outlined)),
        title: Text(account.name),
        subtitle: Text(
          '${_typeLabel(l10n)} · ${account.archived ? l10n.archived : l10n.active}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              MoneyFormat.currency(account.currentBalance, locale),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            PopupMenuButton<String>(
              onSelected: (action) => _handle(context, action),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                if (!account.archived)
                  PopupMenuItem(value: 'archive', child: Text(l10n.archive)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, String action) async {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      if (action == 'edit') {
        await _editAccount(context, initial: account);
      } else if (action == 'archive') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l10n.archiveConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.archive),
              ),
            ],
          ),
        );
        if (confirmed == true) await controller.archiveAccount(account.id);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.genericError)));
    }
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card});

  final HealthCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.credit_card_outlined)),
        title: Text(card.name),
        subtitle: Text(
          '${l10n.closingDay}: ${card.closingDay} · ${l10n.dueDay}: ${card.dueDay}'
          '${card.archived ? ' · ${l10n.archived}' : ''}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handle(context, action),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
            PopupMenuItem(value: 'purchase', child: Text(l10n.newPurchase)),
            PopupMenuItem(value: 'invoices', child: Text(l10n.viewInvoices)),
            if (!card.archived)
              PopupMenuItem(value: 'archive', child: Text(l10n.archive)),
          ],
        ),
        onTap: () => _showInvoices(context),
      ),
    );
  }

  Future<void> _handle(BuildContext context, String action) async {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      switch (action) {
        case 'edit':
          await _editCard(context, initial: card);
        case 'purchase':
          await _addPurchase(context);
        case 'invoices':
          await _showInvoices(context);
        case 'archive':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              content: Text(l10n.archiveConfirmation),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.archive),
                ),
              ],
            ),
          );
          if (confirmed == true) await controller.archiveCard(card.id);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.genericError)));
    }
  }

  Future<void> _addPurchase(BuildContext context) async {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);
    final draft = await showDialog<_PurchaseDraft>(
      context: context,
      builder: (context) => _PurchaseDialog(currency: controller.currency),
    );
    if (draft == null || !context.mounted) return;
    try {
      await controller.createCardPurchase(
        cardId: card.id,
        amount: draft.amount,
        description: draft.description,
        category: draft.category,
        purchaseDate: draft.purchaseDate,
        installmentCount: draft.installmentCount,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.genericError)));
    }
  }

  Future<void> _showInvoices(BuildContext context) async {
    final controller = HealthScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InvoicesSheet(card: card, controller: controller),
    );
  }
}

class _InvoicesSheet extends StatefulWidget {
  const _InvoicesSheet({required this.card, required this.controller});

  final HealthCard card;
  final HealthController controller;

  @override
  State<_InvoicesSheet> createState() => _InvoicesSheetState();
}

class _InvoicesSheetState extends State<_InvoicesSheet> {
  late Future<List<CardInvoice>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.getInvoices(widget.card.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<List<CardInvoice>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final invoices = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.card.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(l10n.invoice, style: const TextStyle(color: HealthColors.textMuted)),
                const SizedBox(height: 12),
                if (invoices.isEmpty)
                  Text(l10n.noInvoices)
                else
                  ...invoices.map(
                    (invoice) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(MoneyFormat.currency(invoice.amount, locale)),
                      subtitle: Text(
                        '${MoneyFormat.date(invoice.dueDate, locale)}'
                        '${invoice.paid ? ' · ${l10n.done}' : ''}',
                      ),
                      trailing: invoice.paid
                          ? null
                          : TextButton(
                              onPressed: () => _pay(invoice),
                              child: Text(l10n.payInvoice),
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pay(CardInvoice invoice) async {
    final accounts = widget.controller.accounts
        .where((account) => !account.archived)
        .toList(growable: false);
    if (accounts.isEmpty) return;
    final accountId = accounts.length == 1
        ? accounts.first.id
        : await showDialog<int>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text(AppLocalizations.of(context).sourceAccount),
              children: accounts
                  .map(
                    (account) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, account.id),
                      child: Text(account.name),
                    ),
                  )
                  .toList(growable: false),
            ),
          );
    if (accountId == null || !mounted) return;
    try {
      await widget.controller.payInvoice(
        invoiceId: invoice.id,
        accountId: accountId,
        paymentDate: DateTime.now(),
      );
      if (!mounted) return;
      setState(() => _future = widget.controller.getInvoices(widget.card.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).genericError)),
      );
    }
  }
}

Future<void> _editAccount(BuildContext context, {HealthAccount? initial}) async {
  final controller = HealthScope.of(context);
  final draft = await showDialog<_AccountDraft>(
    context: context,
    builder: (context) => _AccountDialog(currency: controller.currency, initial: initial),
  );
  if (draft == null || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  try {
    if (initial == null) {
      await controller.createAccount(
        name: draft.name,
        type: draft.type,
        initialBalance: draft.initialBalance,
        referenceDate: draft.referenceDate,
      );
    } else {
      await controller.updateAccount(
        HealthAccount(
          id: initial.id,
          name: draft.name,
          type: draft.type,
          initialBalance: draft.initialBalance,
          balanceReferenceDate: draft.referenceDate,
          currentBalance: initial.currentBalance,
          archived: initial.archived,
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.genericError)));
  }
}

Future<void> _editCard(BuildContext context, {HealthCard? initial}) async {
  final controller = HealthScope.of(context);
  final draft = await showDialog<_CardDraft>(
    context: context,
    builder: (context) => _CardDialog(initial: initial),
  );
  if (draft == null || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  try {
    if (initial == null) {
      await controller.createCard(
        name: draft.name,
        closingDay: draft.closingDay,
        dueDay: draft.dueDay,
      );
    } else {
      await controller.updateCard(
        HealthCard(
          id: initial.id,
          name: draft.name,
          currency: initial.currency,
          closingDay: draft.closingDay,
          dueDay: draft.dueDay,
          archived: initial.archived,
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.genericError)));
  }
}

final class _AccountDraft {
  const _AccountDraft({
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.referenceDate,
  });

  final String name;
  final AccountType type;
  final Money initialBalance;
  final DateTime referenceDate;
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.currency, this.initial});

  final CurrencyCode currency;
  final HealthAccount? initial;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late AccountType _type;
  late DateTime _referenceDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name);
    _balance = TextEditingController(
      text: initial?.initialBalance.toDecimalString(),
    );
    _type = initial?.type ?? AccountType.checking;
    _referenceDate = initial?.balanceReferenceDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? l10n.addAccount : l10n.edit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.accountName),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.account),
              items: [
                DropdownMenuItem(
                  value: AccountType.checking,
                  child: Text(l10n.accountChecking),
                ),
                DropdownMenuItem(
                  value: AccountType.savings,
                  child: Text(l10n.accountSavings),
                ),
                DropdownMenuItem(
                  value: AccountType.cash,
                  child: Text(l10n.accountCash),
                ),
                DropdownMenuItem(
                  value: AccountType.other,
                  child: Text(l10n.accountOther),
                ),
              ],
              onChanged: widget.initial == null
                  ? (value) => setState(() => _type = value!)
                  : null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _balance,
              enabled: widget.initial == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.initialBalance),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.balanceReferenceDate),
              subtitle: Text(
                MoneyFormat.date(_referenceDate, Localizations.localeOf(context)),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: widget.initial != null
                  ? null
                  : () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _referenceDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) {
                        setState(() => _referenceDate = selected);
                      }
                    },
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: HealthColors.negative)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final balance = MoneyInput.tryParse(
      _balance.text,
      currency: widget.currency,
      locale: Localizations.localeOf(context),
    );
    if (_name.text.trim().isEmpty || balance == null) {
      setState(() => _error = l10n.invalidMoney);
      return;
    }
    Navigator.pop(
      context,
      _AccountDraft(
        name: _name.text.trim(),
        type: _type,
        initialBalance: balance,
        referenceDate: _referenceDate,
      ),
    );
  }
}

final class _CardDraft {
  const _CardDraft({
    required this.name,
    required this.closingDay,
    required this.dueDay,
  });

  final String name;
  final int closingDay;
  final int dueDay;
}

class _CardDialog extends StatefulWidget {
  const _CardDialog({this.initial});

  final HealthCard? initial;

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  late final TextEditingController _name;
  late final TextEditingController _closingDay;
  late final TextEditingController _dueDay;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name);
    _closingDay = TextEditingController(text: initial?.closingDay.toString());
    _dueDay = TextEditingController(text: initial?.dueDay.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _closingDay.dispose();
    _dueDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? l10n.addCard : l10n.edit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.cardName),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _closingDay,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.closingDay),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dueDay,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.dueDay),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: HealthColors.negative)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final closingDay = int.tryParse(_closingDay.text.trim());
    final dueDay = int.tryParse(_dueDay.text.trim());
    if (_name.text.trim().isEmpty ||
        closingDay == null ||
        closingDay < 1 ||
        closingDay > 31 ||
        dueDay == null ||
        dueDay < 1 ||
        dueDay > 31) {
      setState(() => _error = l10n.requiredField);
      return;
    }
    Navigator.pop(
      context,
      _CardDraft(name: _name.text.trim(), closingDay: closingDay, dueDay: dueDay),
    );
  }
}

final class _PurchaseDraft {
  const _PurchaseDraft({
    required this.amount,
    required this.description,
    required this.category,
    required this.purchaseDate,
    required this.installmentCount,
  });

  final Money amount;
  final String description;
  final String category;
  final DateTime purchaseDate;
  final int installmentCount;
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({required this.currency});

  final CurrencyCode currency;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _amount = TextEditingController();
  final _installments = TextEditingController(text: '1');
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _category.dispose();
    _amount.dispose();
    _installments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newPurchase),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _description,
              decoration: InputDecoration(labelText: l10n.description),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _category,
              decoration: InputDecoration(labelText: l10n.category),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.amount),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _installments,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.installments),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.purchaseDate),
              subtitle: Text(MoneyFormat.date(_date, Localizations.localeOf(context))),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (selected != null) setState(() => _date = selected);
              },
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: HealthColors.negative)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final amount = MoneyInput.tryParse(
      _amount.text,
      currency: widget.currency,
      locale: Localizations.localeOf(context),
    );
    final installmentCount = int.tryParse(_installments.text.trim());
    if (_description.text.trim().isEmpty ||
        _category.text.trim().isEmpty ||
        amount == null ||
        amount.minorUnits <= 0 ||
        installmentCount == null ||
        installmentCount < 1) {
      setState(() => _error = l10n.invalidMoney);
      return;
    }
    Navigator.pop(
      context,
      _PurchaseDraft(
        amount: amount,
        description: _description.text.trim(),
        category: _category.text.trim(),
        purchaseDate: _date,
        installmentCount: installmentCount,
      ),
    );
  }
}
