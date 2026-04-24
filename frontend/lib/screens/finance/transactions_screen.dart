import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/shared/loading_spinner.dart';
import '../../widgets/shared/member_avatar.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final txs = finance.transactions;
    final total = txs.fold<double>(0, (sum, t) => sum + t.amount);

    if (finance.isLoading) return const Scaffold(body: LoadingSpinner());

    final grouped = _groupByMonth(txs);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Transactions', style: TextStyle(fontSize: 16)),
            Text('Total: ${total.toStringAsFixed(0)} Kč',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: txs.isEmpty
          ? const EmptyState(icon: Icons.receipt_long_outlined, message: 'No transactions yet')
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
                    ...items.map((t) => _TxTile(tx: t)),
                  ],
                );
              },
            ),
    );
  }

  Map<String, List<Transaction>> _groupByMonth(List<Transaction> txs) {
    final result = <String, List<Transaction>>{};
    for (final t in txs) {
      final key = DateFormat('MMMM yyyy').format(t.createdAt);
      (result[key] ??= []).add(t);
    }
    return result;
  }
}

class _TxTile extends StatelessWidget {
  final Transaction tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
      onTap: () => _showDetail(context),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _TxDetailSheet(tx: tx),
    );
  }
}

class _TxDetailSheet extends StatelessWidget {
  final Transaction tx;
  const _TxDetailSheet({required this.tx});

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx.description.isNotEmpty ? tx.description : 'Transaction',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Amount: ${tx.amount.toStringAsFixed(2)} Kč'),
          Text('Paid by: ${tx.creditor.name}'),
          Text('Date: ${DateFormat('MMM d, yyyy HH:mm').format(tx.createdAt)}'),
          const SizedBox(height: 16),
          if (!tx.isSettlement)
            OutlinedButton(
              onPressed: () async {
                final canEdit = await finance.canEditTransaction(tx.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (canEdit) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TransactionFormScreen(existing: tx)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This transaction cannot be edited.')),
                  );
                }
              },
              child: const Text('Edit'),
            ),
          const SizedBox(height: 8),
          if (!tx.isSettlement)
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
