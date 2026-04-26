import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/shared/empty_state.dart';
import 'transaction_form_screen.dart';

class ScheduledPaymentsScreen extends StatelessWidget {
  const ScheduledPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final txs = finance.recurringTransactions;

    final grouped = _groupByMonth(txs);

    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Payments')),
      body: txs.isEmpty
          ? const EmptyState(icon: Icons.event_repeat_outlined, message: 'No scheduled payments')
          : ListView.builder(
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final month = grouped.keys.elementAt(i);
                final items = grouped[month]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(month,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    ...items.map((t) => _ScheduledTile(tx: t)),
                  ],
                );
              },
            ),
    );
  }

  Map<String, List<Transaction>> _groupByMonth(List<Transaction> txs) {
    final result = <String, List<Transaction>>{};
    for (final t in txs) {
      final date = t.nextPaymentDate ?? t.createdAt;
      final key = DateFormat('MMMM yyyy').format(date);
      (result[key] ??= []).add(t);
    }
    return result;
  }
}

class _ScheduledTile extends StatelessWidget {
  final Transaction tx;
  const _ScheduledTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final next = tx.nextPaymentDate != null
        ? DateFormat('MMM d').format(tx.nextPaymentDate!)
        : '—';
    return ListTile(
      title: Text(tx.description.isNotEmpty ? tx.description : 'Payment'),
      subtitle: Text('Next: $next · ${tx.recurrenceInterval ?? ''}'),
      trailing: Text('${tx.amount.toStringAsFixed(0)} Kč',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () => _showDetail(context),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _ScheduledDetailSheet(tx: tx),
    );
  }
}

class _ScheduledDetailSheet extends StatelessWidget {
  final Transaction tx;
  const _ScheduledDetailSheet({required this.tx});

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx.description.isNotEmpty ? tx.description : 'Scheduled Payment',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Amount: ${tx.amount.toStringAsFixed(2)} Kč'),
          Text('Recurrence: ${tx.recurrenceInterval ?? '—'}'),
          if (tx.nextPaymentDate != null)
            Text('Next: ${DateFormat('MMM d, yyyy').format(tx.nextPaymentDate!)}'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TransactionFormScreen(existing: tx)),
              );
            },
            child: const Text('Edit'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(context).pop();
              await finance.deleteTransaction(tx.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
