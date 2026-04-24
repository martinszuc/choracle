import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/favorite_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/shopping_provider.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _inputCtrl = TextEditingController();

  // items being assembled before submission
  final List<_PendingItem> _items = [];
  // quantities for favorites (0 = not included)
  final Map<String, int> _favQty = {};

  bool _addToDebts = false;
  bool _isGroup = false;

  @override
  void initState() {
    super.initState();
    final favs = context.read<ShoppingProvider>().favorites;
    for (final f in favs) {
      _favQty[f.id] = 0;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _finalizeInput() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(_PendingItem(name: text));
      _inputCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopping = context.watch<ShoppingProvider>();
    final app = context.read<AppProvider>();
    final favorites = shopping.favorites;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Items')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    decoration: const InputDecoration(hintText: 'Item name'),
                    onSubmitted: (_) => _finalizeInput(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _finalizeInput,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._items.map((item) => _PendingItemRow(
                  item: item,
                  onRemove: () => setState(() => _items.remove(item)),
                  onQtyChange: (q) => setState(() => item.quantity = q),
                )),
            if (favorites.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Favorites', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...favorites.map((f) => _FavoriteRow(
                    fav: f,
                    qty: _favQty[f.id] ?? 0,
                    onQtyChange: (q) => setState(() => _favQty[f.id] = q),
                  )),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add to debts'),
              value: _addToDebts,
              onChanged: (v) => setState(() => _addToDebts = v),
            ),
            if (_addToDebts)
              Row(
                children: [
                  const Text('Split: '),
                  IconButton(
                    icon: Icon(Icons.person, color: !_isGroup ? Colors.deepPurple : Colors.grey),
                    onPressed: () => setState(() => _isGroup = false),
                    tooltip: 'Single person',
                  ),
                  IconButton(
                    icon: Icon(Icons.group, color: _isGroup ? Colors.deepPurple : Colors.grey),
                    onPressed: () => setState(() => _isGroup = true),
                    tooltip: 'Group',
                  ),
                ],
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _submit(context, app, shopping),
              child: const Text('Add to List'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, AppProvider app, ShoppingProvider shopping) async {
    final currentMember = app.currentMember;
    if (currentMember == null) return;

    final debtOption = _addToDebts ? (_isGroup ? 'group' : 'single') : 'none';

    final itemsData = <Map<String, dynamic>>[
      ..._items
          .where((i) => i.quantity > 0)
          .map((i) => {
                'name': i.name,
                'quantity': i.quantity,
                'created_by_id': currentMember.id,
                'debt_option': debtOption,
              }),
      ...shopping.favorites
          .where((f) => (_favQty[f.id] ?? 0) > 0)
          .map((f) => {
                'name': f.name,
                'quantity': _favQty[f.id],
                'created_by_id': currentMember.id,
                'debt_option': debtOption,
              }),
    ];

    if (itemsData.isEmpty) return;

    await shopping.addItems(itemsData);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _PendingItem {
  String name;
  int quantity;
  _PendingItem({required this.name, this.quantity = 1});
}

class _PendingItemRow extends StatelessWidget {
  final _PendingItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChange;

  const _PendingItemRow({required this.item, required this.onRemove, required this.onQtyChange});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: item.quantity > 1 ? () => onQtyChange(item.quantity - 1) : null,
          ),
          Text('${item.quantity}'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => onQtyChange(item.quantity + 1),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
        ],
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  final FavoriteItem fav;
  final int qty;
  final ValueChanged<int> onQtyChange;

  const _FavoriteRow({required this.fav, required this.qty, required this.onQtyChange});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(fav.name, style: qty == 0 ? const TextStyle(color: Colors.grey) : null),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: qty > 0 ? () => onQtyChange(qty - 1) : null,
          ),
          Text('$qty'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => onQtyChange(qty + 1),
          ),
        ],
      ),
    );
  }
}
