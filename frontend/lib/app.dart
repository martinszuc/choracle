import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/api_client.dart';
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
  StreamSubscription<String>? _successSub;

  final _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _successSub = apiSuccessEvents.stream.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(msg),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 140,
        ));
    });
  }

  @override
  void dispose() {
    _successSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    // show wake-up screen while the Render free-tier backend is cold-starting
    if (app.isLoading && app.household == null) {
      return const _WakeUpScreen();
    }

    if (app.error != null && app.household == null) {
      return _ErrorScreen(
        message: app.error!,
        onRetry: () => context.read<AppProvider>().initialize(),
      );
    }

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
      body: Stack(
        children: [
          IndexedStack(
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
          // thin progress bar at the top — shown whenever any request is in flight
          ValueListenableBuilder<int>(
            valueListenable: apiInFlight,
            builder: (context2, count, child) => count > 0
                ? const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : const SizedBox.shrink(),
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
              final ok = await context.read<AppProvider>().addMember(name);
              if (!context.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.read<AppProvider>().error ?? 'Failed to add member')),
                );
              }
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

class _WakeUpScreen extends StatelessWidget {
  const _WakeUpScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Connecting…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Server is waking up, this can take\nup to 30 seconds on first launch.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey)),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Could not reach server',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Checklist:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const _CheckItem('Device has internet — open a browser and try google.com'),
              const _CheckItem('Open in browser: choracle-backend.onrender.com/api/household/'),
              const _CheckItem('Try switching between WiFi and mobile data'),
              const _CheckItem('Backend URL: https://choracle-backend.onrender.com'),
              const SizedBox(height: 24),
              Center(
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
