import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shopping_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../widgets/shared/app_header.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/shared/loading_spinner.dart';
import '../../widgets/shared/member_avatar.dart';
import 'add_item_screen.dart';
import 'shopping_settings_screen.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final shopping = context.watch<ShoppingProvider>();

    var items = shopping.items;
    if (shopping.hideChecked) items = items.where((i) => !i.purchased).toList();
    items.sort((a, b) {
      if (a.purchased == b.purchased) return a.createdAt.compareTo(b.createdAt);
      return a.purchased ? 1 : -1;
    });

    final bought = shopping.items.where((i) => i.purchased).length;
    final total = shopping.items.length;

    return Scaffold(
      appBar: AppHeader(
        title: app.household?.name ?? 'Choracle',
        subtitle: '$bought/$total items bought',
        currentMember: app.currentMember,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShoppingSettingsScreen()),
            ),
          ),
        ],
      ),
      body: shopping.isLoading
          ? const LoadingSpinner()
          : RefreshIndicator(
              onRefresh: () => context.read<ShoppingProvider>().fetchItems(),
              child: items.isEmpty
                  ? const EmptyState(icon: Icons.shopping_cart_outlined, message: 'Your list is empty')
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _ShoppingItemTile(item: items[i]),
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddItemScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  const _ShoppingItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final shopping = context.read<ShoppingProvider>();
    final app = context.read<AppProvider>();

    return Card(
      child: ListTile(
        leading: Checkbox(
          value: item.purchased,
          onChanged: (_) => item.purchased
              ? _handleUnpurchase(context, app, shopping)
              : _handlePurchase(context, app, shopping),
        ),
        title: Text(
          item.name,
          style: item.purchased
              ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
              : null,
        ),
        subtitle: item.quantity > 1 ? Text('Qty: ${item.quantity}') : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shopping.showAvatars)
              MemberAvatar(member: item.createdBy, radius: 14),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => shopping.deleteItem(item.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUnpurchase(
    BuildContext context,
    AppProvider app,
    ShoppingProvider shopping,
  ) async {
    if (item.linkedTransactionId != null) {
      final finance = context.read<FinanceProvider>();
      await finance.deleteTransaction(item.linkedTransactionId!);
    }
    if (!context.mounted) return;
    await shopping.togglePurchased(item.id, purchased: false);
  }

  Future<void> _handlePurchase(
    BuildContext context,
    AppProvider app,
    ShoppingProvider shopping,
  ) async {
    final currentMember = app.currentMember;
    if (currentMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select who you are first (menu → your name)')),
      );
      return;
    }

    // no-debt item or single-debt where buyer is the creator — just mark purchased
    final skipDebt = item.debtOption == 'none' ||
        (item.debtOption == 'single' && currentMember.id == item.createdBy.id);

    if (skipDebt) {
      await shopping.togglePurchased(item.id, purchased: true, purchasedById: currentMember.id);
      return;
    }

    // debt-linked purchase — ask for price
    final priceCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter price'),
        content: TextField(
          controller: priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'Kč'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final amount = double.tryParse(priceCtrl.text);
    if (amount == null || amount <= 0) return;

    final members = app.members;
    final participantIds = item.debtOption == 'group'
        ? members.map((m) => m.id).toList()
        : [currentMember.id, item.createdBy.id];

    final financeProvider = context.read<FinanceProvider>();
    await financeProvider.addTransaction({
      'creditor_id': currentMember.id,
      'participant_ids': participantIds,
      'amount': amount,
      'description': item.name,
      'is_recurring': false,
    });

    if (!context.mounted) return;
    final txId = financeProvider.transactions.isNotEmpty ? financeProvider.transactions.first.id : null;
    await shopping.togglePurchased(item.id, purchased: true, purchasedById: currentMember.id, linkedTransactionId: txId);
  }
}
