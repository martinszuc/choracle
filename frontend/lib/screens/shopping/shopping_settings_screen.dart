import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shopping_provider.dart';

class ShoppingSettingsScreen extends StatefulWidget {
  const ShoppingSettingsScreen({super.key});

  @override
  State<ShoppingSettingsScreen> createState() => _ShoppingSettingsScreenState();
}

class _ShoppingSettingsScreenState extends State<ShoppingSettingsScreen> {
  final _newFavCtrl = TextEditingController();
  bool _editMode = false;

  @override
  void dispose() {
    _newFavCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopping = context.watch<ShoppingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Settings'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _editMode = !_editMode),
            child: Text(_editMode ? 'Done' : 'Edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Show member avatars'),
            value: shopping.showAvatars,
            onChanged: shopping.setShowAvatars,
          ),
          SwitchListTile(
            title: const Text('Hide purchased items'),
            value: shopping.hideChecked,
            onChanged: shopping.setHideChecked,
          ),
          const Divider(),
          const Text('Favorites', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ...shopping.favorites.map((f) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(f.name),
                trailing: _editMode
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => shopping.deleteFavorite(f.id),
                      )
                    : null,
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newFavCtrl,
                  decoration: const InputDecoration(hintText: 'New favorite item'),
                  onSubmitted: (_) => _addFavorite(shopping),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _addFavorite(shopping),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addFavorite(ShoppingProvider shopping) async {
    final name = _newFavCtrl.text.trim();
    if (name.isEmpty) return;
    await shopping.addFavorite(name);
    _newFavCtrl.clear();
  }
}
