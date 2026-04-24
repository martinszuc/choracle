import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/member.dart';
import '../../models/transaction.dart';
import '../../providers/app_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../widgets/shared/member_avatar.dart';

const _recurrenceOptions = ['weekly', 'biweekly', 'monthly', 'semiannually'];

class TransactionFormScreen extends StatefulWidget {
  final Transaction? existing;
  const TransactionFormScreen({super.key, this.existing});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  Member? _creditor;
  final Set<String> _participantIds = {};
  bool _isScheduled = false;
  DateTime? _startDate;
  String _recurrence = 'monthly';

  @override
  void initState() {
    super.initState();
    final tx = widget.existing;
    if (tx != null) {
      _descCtrl.text = tx.description;
      _amountCtrl.text = tx.amount.toStringAsFixed(2);
      _creditor = tx.creditor;
      _participantIds.addAll(tx.participants.map((p) => p.id));
      _isScheduled = tx.isRecurring;
      _startDate = tx.startDate;
      _recurrence = tx.recurrenceInterval ?? 'monthly';
    } else {
      final app = context.read<AppProvider>();
      _creditor = app.currentMember;
      _participantIds.addAll(app.members.map((m) => m.id));
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final members = app.members;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final share = _participantIds.isNotEmpty ? amount / _participantIds.length : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit Transaction' : 'New Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            const Text('Creditor (paid by)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: members.map((m) {
                final selected = m.id == _creditor?.id;
                return GestureDetector(
                  onTap: () => setState(() => _creditor = m),
                  child: Opacity(
                    opacity: selected ? 1 : 0.4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MemberAvatar(member: m, radius: 22),
                        Text(m.name, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', suffixText: 'Kč'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            const Text('Participants', style: TextStyle(fontWeight: FontWeight.w600)),
            ...members.map((m) {
              final included = _participantIds.contains(m.id);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: included,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _participantIds.add(m.id);
                  } else {
                    _participantIds.remove(m.id);
                  }
                }),
                title: Text(m.name),
                secondary: MemberAvatar(member: m, radius: 16),
                subtitle: included
                    ? Text('${share.toStringAsFixed(2)} Kč per person')
                    : null,
              );
            }),
            if (widget.existing == null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Shared shopping items'),
                onPressed: () => _pickShoppingItems(context),
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Scheduled payment'),
              value: _isScheduled,
              onChanged: (v) => setState(() => _isScheduled = v ?? false),
            ),
            if (_isScheduled) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start date'),
                subtitle: Text(_startDate != null
                    ? DateFormat('MMM d, yyyy').format(_startDate!)
                    : 'Select date'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurrence'),
                subtitle: Text(_recurrence),
                trailing: const Icon(Icons.expand_more),
                onTap: () => _pickRecurrence(context),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _submit(context),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickShoppingItems(BuildContext context) async {
    final shoppingItems = context.read<ShoppingProvider>().items
        .where((i) => !i.purchased && i.debtOption == 'group')
        .toList();

    if (shoppingItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No group-debt shopping items available')),
      );
      return;
    }

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        final chosen = <String>{};
        return StatefulBuilder(builder: (_, set) {
          return AlertDialog(
            title: const Text('Shopping items'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: shoppingItems.map((i) {
                  return CheckboxListTile(
                    title: Text(i.name),
                    value: chosen.contains(i.id),
                    onChanged: (v) => set(() {
                      if (v == true) chosen.add(i.id); else chosen.remove(i.id);
                    }),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(chosen.toList()),
                child: const Text('Select'),
              ),
            ],
          );
        });
      },
    );

    if (selected == null || selected.isEmpty) return;
    final names = context.read<ShoppingProvider>().items
        .where((i) => selected.contains(i.id))
        .map((i) => i.name)
        .join(', ');
    setState(() => _descCtrl.text = names);
  }

  void _pickRecurrence(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: _recurrenceOptions.map((r) => ListTile(
              title: Text(r),
              trailing: r == _recurrence ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => _recurrence = r);
                Navigator.of(ctx).pop();
              },
            )).toList(),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (_creditor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a creditor')),
      );
      return;
    }

    final data = <String, dynamic>{
      'creditor_id': _creditor!.id,
      'participant_ids': _participantIds.toList(),
      'amount': amount,
      'description': _descCtrl.text.trim(),
      'is_recurring': _isScheduled,
    };

    if (_isScheduled) {
      data['recurrence_interval'] = _recurrence;
      if (_startDate != null) {
        data['start_date'] = DateFormat('yyyy-MM-dd').format(_startDate!);
      }
    }

    final finance = context.read<FinanceProvider>();
    if (widget.existing != null) {
      await finance.editTransaction(widget.existing!.id, data);
    } else {
      await finance.addTransaction(data);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
