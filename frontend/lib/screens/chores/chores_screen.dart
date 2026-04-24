import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/chores_provider.dart';
import '../../models/chore.dart';
import '../../widgets/shared/app_header.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/shared/loading_spinner.dart';
import '../../widgets/shared/member_avatar.dart';
import 'add_chore_screen.dart';
import 'stats_screen.dart';

class ChoresScreen extends StatefulWidget {
  const ChoresScreen({super.key});

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final chores = context.watch<ChoresProvider>();
    final currentMember = app.currentMember;

    final myChores = chores.chores
        .where((c) => !c.completed && c.assignedTo?.id == currentMember?.id)
        .toList();
    final othersChores = chores.chores
        .where((c) => !c.completed && c.assignedTo?.id != currentMember?.id)
        .toList();
    final completed = chores.chores.where((c) => c.completed).toList();
    final total = chores.chores.length;
    final doneCount = completed.length;

    return Scaffold(
      appBar: AppHeader(
        title: app.household?.name ?? 'Choracle',
        subtitle: '$doneCount/$total chores done this week',
        currentMember: currentMember,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
        ],
      ),
      body: chores.isLoading
          ? const LoadingSpinner()
          : RefreshIndicator(
              onRefresh: () => context.read<ChoresProvider>().fetchChores(),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _SectionHeader(title: 'Your tasks', count: myChores.length),
                  if (myChores.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No tasks assigned to you.',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ...myChores.map((c) => _MyChoreCard(chore: c)),
                  const SizedBox(height: 8),
                  _SectionHeader(title: "Others' tasks", count: othersChores.length),
                  ...othersChores.map((c) => _OtherChoreCard(chore: c)),
                  const SizedBox(height: 8),
                  _SectionHeader(title: 'Completed this week', count: completed.length),
                  if (completed.isEmpty)
                    const EmptyState(icon: Icons.check_circle_outline, message: 'No completed chores yet'),
                  ...completed.map((c) => _CompletedChoreCard(chore: c)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddChoreScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        '$title ($count)',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _MyChoreCard extends StatelessWidget {
  final Chore chore;
  const _MyChoreCard({required this.chore});

  Color _borderColor() {
    final age = DateTime.now().difference(chore.createdAt).inDays;
    if (age >= 3) return Colors.red.shade400;
    if (age >= 2) return Colors.orange.shade400;
    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final currentMemberId = context.read<AppProvider>().currentMember?.id ?? '';
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _borderColor(), width: 1.5),
      ),
      child: ListTile(
        title: Text(chore.name),
        trailing: FilledButton(
          onPressed: () => context.read<ChoresProvider>().completeChore(chore.id, currentMemberId),
          child: const Text('Done'),
        ),
      ),
    );
  }
}

class _OtherChoreCard extends StatelessWidget {
  final Chore chore;
  const _OtherChoreCard({required this.chore});

  @override
  Widget build(BuildContext context) {
    final currentMemberId = context.read<AppProvider>().currentMember?.id ?? '';
    return Card(
      child: ListTile(
        leading: MemberAvatar(member: chore.assignedTo),
        title: Text(chore.name),
        subtitle: Text(chore.assignedTo?.name ?? ''),
        trailing: OutlinedButton(
          onPressed: () => context.read<ChoresProvider>().stealChore(chore.id, currentMemberId),
          child: const Text('Take Over'),
        ),
      ),
    );
  }
}

class _CompletedChoreCard extends StatelessWidget {
  final Chore chore;
  const _CompletedChoreCard({required this.chore});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade100,
      child: ListTile(
        leading: MemberAvatar(member: chore.completedBy),
        title: Text(
          chore.name,
          style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey),
        ),
        subtitle: chore.originalAssignedTo != null &&
                chore.originalAssignedTo?.id != chore.completedBy?.id
            ? Text('Originally: ${chore.originalAssignedTo?.name}')
            : null,
      ),
    );
  }
}
