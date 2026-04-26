import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/chores_provider.dart';
import 'providers/shopping_provider.dart';
import 'providers/finance_provider.dart';
import 'screens/chores/chores_screen.dart';
import 'screens/shopping/shopping_screen.dart';
import 'screens/finance/finance_screen.dart';
import 'widgets/shared/member_avatar.dart';
import 'theme/app_theme.dart';

class ChoracleApp extends StatelessWidget {
  const ChoracleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()..initialize()),
        ChangeNotifierProxyProvider<AppProvider, ChoresProvider>(
          create: (_) => ChoresProvider(),
          update: (_, app, chores) => chores!..setHouseholdId(app.householdId),
        ),
        ChangeNotifierProxyProvider<AppProvider, ShoppingProvider>(
          create: (_) => ShoppingProvider(),
          update: (_, app, shopping) => shopping!..setHouseholdId(app.householdId),
        ),
        ChangeNotifierProxyProvider<AppProvider, FinanceProvider>(
          create: (_) => FinanceProvider(),
          update: (_, app, finance) => finance!..setHouseholdId(app.householdId),
        ),
      ],
      child: MaterialApp(
        title: 'Choracle',
        theme: buildAppTheme(),
        home: const _HomeShell(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _selectedIndex = 0;

  final _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final members = app.members;

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final isSelected = m.id == app.currentMember?.id;
                    return ListTile(
                      leading: MemberAvatar(member: m),
                      title: Text(m.name),
                      selected: isSelected,
                      selectedTileColor: kPrimaryColor.withValues(alpha: 0.1),
                      onTap: () {
                        app.selectMember(m);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('Add member'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showAddMemberDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Navigator(
            key: _navigatorKeys[0],
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const ChoresScreen()),
          ),
          Navigator(
            key: _navigatorKeys[1],
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const ShoppingScreen()),
          ),
          Navigator(
            key: _navigatorKeys[2],
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const FinanceScreen()),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Chores',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Shopping',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Finance',
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add member'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              await context.read<AppProvider>().addMember(name);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    // controller disposed when dialog is closed via StatefulWidget, but since
    // AlertDialog is not a StatefulWidget here we rely on the GC — acceptable
    // for a simple dialog without pending lifecycle
  }
}
