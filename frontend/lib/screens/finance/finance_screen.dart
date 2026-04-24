import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/debt.dart';
import '../../models/transaction.dart';
import '../../providers/app_provider.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/shared/app_header.dart';
import '../../widgets/shared/loading_spinner.dart';
import '../../widgets/shared/member_avatar.dart';
import 'transaction_form_screen.dart';
import 'transactions_screen.dart';
import 'scheduled_payments_screen.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final finance = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppHeader(
        title: app.household?.name ?? 'Choracle',
        subtitle: '${finance.debts.length} active debts',
        currentMember: app.currentMember,
      ),
      body: finance.isLoading
          ? const LoadingSpinner()
          : RefreshIndicator(
              onRefresh: () => context.read<FinanceProvider>().fetchAll(),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _sectionTitle('Debts'),
                  if (finance.debts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No active debts', style: TextStyle(color: Colors.grey)),
                    ),
                  ...finance.debts.map((d) => _DebtRow(debt: d)),
                  const SizedBox(height: 12),
                  _sectionTitle('Upcoming payments'),
                  if (finance.recurringTransactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No scheduled payments', style: TextStyle(color: Colors.grey)),
                    )
                  else ...[
                    _RecurringRow(tx: finance.recurringTransactions.first),
                    if (finance.recurringTransactions.length > 1)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ScheduledPaymentsScreen()),
                        ),
                        child: const Text('Show all'),
                      ),
                  ],
                  const SizedBox(height: 12),
                  _sectionTitle('Recent transactions'),
                  ...finance.transactions.take(3).map((t) => _TransactionRow(tx: t)),
                  if (finance.transactions.length > 3)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                      ),
                      child: const Text('Show all'),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}

class _DebtRow extends StatelessWidget {
  final Debt debt;
  const _DebtRow({required this.debt});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showSettleModal(context),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              MemberAvatar(name: debt.debtorName, color: debt.debtorColor),
              const SizedBox(width: 8),
              Text(debt.debtorName, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('${debt.amount.toStringAsFixed(0)} Kč',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MemberAvatar(name: debt.creditorName, color: debt.creditorColor),
              const SizedBox(width: 8),
              Text(debt.creditorName, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettleModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _SettleSheet(debt: debt),
    );
  }
}

class _SettleSheet extends StatefulWidget {
  final Debt debt;
  const _SettleSheet({required this.debt});

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  bool _partial = false;
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Settle debt', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Total owed: ${widget.debt.amount.toStringAsFixed(2)} Kč'),
          const SizedBox(height: 12),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Full'),
                selected: !_partial,
                onSelected: (_) => setState(() => _partial = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Partial'),
                selected: _partial,
                onSelected: (_) => setState(() => _partial = true),
              ),
            ],
          ),
          if (_partial) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', suffixText: 'Kč'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final amount = _partial ? double.tryParse(_amountCtrl.text) : null;
              Navigator.of(context).pop();
              await finance.settleDebt(
                debtorId: widget.debt.debtorId,
                creditorId: widget.debt.creditorId,
                amount: amount,
              );
            },
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  final Transaction tx;
  const _RecurringRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final next = tx.nextPaymentDate != null
        ? DateFormat('MMM d').format(tx.nextPaymentDate!)
        : '—';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(tx.description.isNotEmpty ? tx.description : 'Payment'),
      subtitle: Text('Next: $next'),
      trailing: Text('${tx.amount.toStringAsFixed(0)} Kč',
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction tx;
  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: MemberAvatar(member: tx.creditor),
        title: Text(tx.description.isNotEmpty ? tx.description : 'Transaction'),
        subtitle: Text(DateFormat('MMM d, HH:mm').format(tx.createdAt)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${tx.amount.toStringAsFixed(0)} Kč',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            ...tx.participants.take(3).map((p) => Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: MemberAvatar(member: p, radius: 12),
                )),
          ],
        ),
      ),
    );
  }
}
