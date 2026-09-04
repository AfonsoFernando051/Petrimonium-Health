import 'package:flutter/material.dart';

import '../../../core/app/health_scope.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/health_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../health/domain/health_models.dart';
import '../../health/presentation/health_controller.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int? _accountId;
  TransactionStatus? _status;

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final rows = controller.transactions.where((transaction) {
      return (_accountId == null || transaction.accountId == _accountId) &&
          (_status == null || transaction.status == _status);
    }).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.transactionsTab,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: HealthColors.textPrimary,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: controller.accounts.isEmpty
                        ? null
                        : () => _editTransaction(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addTransaction),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _accountId,
                      decoration: InputDecoration(labelText: l10n.account),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.allAccounts)),
                        ...controller.accounts.where((item) => !item.archived).map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<TransactionStatus?>(
                      initialValue: _status,
                      decoration: InputDecoration(labelText: l10n.status),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.allStatuses)),
                        DropdownMenuItem(
                          value: TransactionStatus.planned,
                          child: Text(l10n.planned),
                        ),
                        DropdownMenuItem(
                          value: TransactionStatus.realized,
                          child: Text(l10n.realized),
                        ),
                      ],
                      onChanged: (value) => setState(() => _status = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Text(l10n.noTransactions))
              : RefreshIndicator(
                  onRefresh: controller.refreshData,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final transaction = rows[index];
                      final isIncome = transaction.type == TransactionType.income;
                      final editable = transaction.type == TransactionType.income ||
                          transaction.type == TransactionType.expense;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            ),
                          ),
                          title: Text(transaction.description),
                          subtitle: Text(
                            '${MoneyFormat.date(transaction.date, locale)} · '
                            '${transaction.status == TransactionStatus.planned ? l10n.planned : l10n.realized}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                MoneyFormat.currency(transaction.amount, locale),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isIncome
                                      ? HealthColors.positive
                                      : HealthColors.negative,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (action) => _handleAction(
                                  context,
                                  transaction,
                                  action,
                                ),
                                itemBuilder: (context) => [
                                  if (editable)
                                    PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                                  if (editable &&
                                      transaction.status == TransactionStatus.planned)
                                    PopupMenuItem(
                                      value: 'confirm',
                                      child: Text(l10n.confirmTransaction),
                                    ),
                                  if (editable)
                                    PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    HealthTransaction transaction,
    String action,
  ) async {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      if (action == 'edit') {
        await _editTransaction(context, initial: transaction);
      } else if (action == 'confirm') {
        await controller.confirmTransaction(transaction.id);
      } else if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l10n.deleteConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await controller.deleteTransaction(transaction.id);
        }
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.genericError)),
      );
    }
  }

  Future<void> _editTransaction(
    BuildContext context, {
    HealthTransaction? initial,
  }) async {
    final controller = HealthScope.of(context);
    final draft = await showDialog<_TransactionDraft>(
      context: context,
      builder: (context) => _TransactionDialog(
        accounts: controller.accounts.where((item) => !item.archived).toList(),
        currency: controller.currency,
        initial: initial,
      ),
    );
    if (draft == null || !context.mounted) return;
    try {
      if (initial == null) {
        await controller.createTransaction(
          accountId: draft.accountId,
          type: draft.type,
          status: draft.status,
          amount: draft.amount,
          description: draft.description,
          category: draft.category,
          date: draft.date,
          recurring: draft.recurring,
        );
      } else {
        await controller.updateTransaction(
          HealthTransaction(
            id: initial.id,
            accountId: draft.accountId,
            type: draft.type,
            status: draft.status,
            amount: draft.amount,
            description: draft.description,
            category: draft.category,
            date: draft.date,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).genericError)),
      );
    }
  }
}

final class _TransactionDraft {
  const _TransactionDraft({
    required this.accountId,
    required this.type,
    required this.status,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    required this.recurring,
  });

  final int accountId;
  final TransactionType type;
  final TransactionStatus status;
  final Money amount;
  final String description;
  final String category;
  final DateTime date;
  final bool recurring;
}

class _TransactionDialog extends StatefulWidget {
  const _TransactionDialog({
    required this.accounts,
    required this.currency,
    this.initial,
  });

  final List<HealthAccount> accounts;
  final CurrencyCode currency;
  final HealthTransaction? initial;

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  late int _accountId;
  late TransactionType _type;
  late TransactionStatus _status;
  late DateTime _date;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _category;
  bool _recurring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _accountId = initial?.accountId ?? widget.accounts.first.id;
    _type = initial?.type ?? TransactionType.expense;
    _status = initial?.status ?? TransactionStatus.planned;
    _date = initial?.date ?? DateTime.now();
    _description = TextEditingController(text: initial?.description);
    _amount = TextEditingController(text: initial?.amount.toDecimalString());
    _category = TextEditingController(text: initial?.category);
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? l10n.addTransaction : l10n.edit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              decoration: InputDecoration(labelText: l10n.account),
              items: widget.accounts
                  .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                  .toList(),
              onChanged: (value) => setState(() => _accountId = value!),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<TransactionType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.status),
              items: [
                DropdownMenuItem(value: TransactionType.income, child: Text(l10n.income)),
                DropdownMenuItem(value: TransactionType.expense, child: Text(l10n.expense)),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<TransactionStatus>(
              initialValue: _status,
              decoration: InputDecoration(labelText: l10n.status),
              items: [
                DropdownMenuItem(value: TransactionStatus.planned, child: Text(l10n.planned)),
                DropdownMenuItem(value: TransactionStatus.realized, child: Text(l10n.realized)),
              ],
              onChanged: (value) => setState(() => _status = value!),
            ),
            const SizedBox(height: 10),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.date),
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
            if (widget.initial == null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.recurringMonthly),
                value: _recurring,
                onChanged: (value) => setState(() => _recurring = value),
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
    if (_description.text.trim().isEmpty ||
        _category.text.trim().isEmpty ||
        amount == null ||
        amount.minorUnits <= 0) {
      setState(() => _error = l10n.invalidMoney);
      return;
    }
    Navigator.pop(
      context,
      _TransactionDraft(
        accountId: _accountId,
        type: _type,
        status: _status,
        amount: amount,
        description: _description.text.trim(),
        category: _category.text.trim(),
        date: _date,
        recurring: _recurring,
      ),
    );
  }
}
