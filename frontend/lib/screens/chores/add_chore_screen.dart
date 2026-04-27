import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/member.dart';
import '../../providers/app_provider.dart';
import '../../providers/chores_provider.dart';
import '../../widgets/shared/member_avatar.dart';

class AddChoreScreen extends StatefulWidget {
  const AddChoreScreen({super.key});

  @override
  State<AddChoreScreen> createState() => _AddChoreScreenState();
}

class _AddChoreScreenState extends State<AddChoreScreen> {
  int _tabIndex = 0;

  // immediate form
  final _nameCtrl = TextEditingController();
  Member? _selectedMember;

  // scheduled form
  final _schedNameCtrl = TextEditingController();
  final _freqCtrl = TextEditingController(text: '7');
  DateTime _startDate = DateTime.now();
  Member? _schedMember;

  @override
  void initState() {
    super.initState();
    // default both assignee fields to the current member
    final current = context.read<AppProvider>().currentMember;
    _selectedMember = current;
    _schedMember = current;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schedNameCtrl.dispose();
    _freqCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final chores = context.watch<ChoresProvider>();
    final members = app.members;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Chore')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Immediate')),
                ButtonSegment(value: 1, label: Text('Scheduled')),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (s) => setState(() => _tabIndex = s.first),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _tabIndex == 0
                  ? _buildImmediateForm(members, chores)
                  : _buildScheduledForm(members, chores),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmediateForm(List<Member> members, ChoresProvider chores) {
    // sync the selected member to the matching instance from the current members list
    final resolvedMember = _resolveMember(_selectedMember, members);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Chore name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _MemberDropdown(
          label: 'Assign to',
          members: members,
          value: resolvedMember,
          onChanged: (m) => setState(() => _selectedMember = m),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _nameCtrl.text.trim().isEmpty || _selectedMember == null
              ? null
              : () async {
                  final name = _nameCtrl.text.trim();
                  await chores.addChore(name, _selectedMember!.id);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
          child: const Text('Add Chore'),
        ),
      ],
    );
  }

  /// finds the matching member instance from the current list by id
  Member? _resolveMember(Member? stored, List<Member> members) {
    if (stored == null) return null;
    try {
      return members.firstWhere((m) => m.id == stored.id);
    } catch (_) {
      return null;
    }
  }

  Widget _buildScheduledForm(List<Member> members, ChoresProvider chores) {
    final resolvedSchedMember = _resolveMember(_schedMember, members);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _schedNameCtrl,
          decoration: const InputDecoration(labelText: 'Chore name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _MemberDropdown(
          label: 'Assign to',
          members: members,
          value: resolvedSchedMember,
          onChanged: (m) => setState(() => _schedMember = m),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _freqCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Frequency (days)'),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Start date'),
          subtitle: Text(DateFormat('MMM d, yyyy').format(_startDate)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _startDate = picked);
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _schedNameCtrl.text.trim().isEmpty
              ? null
              : () async {
                  final name = _schedNameCtrl.text.trim();
                  final freq = int.tryParse(_freqCtrl.text) ?? 7;
                  await chores.addDefaultChore(
                    name, freq, _startDate,
                    assignedToId: _schedMember?.id,
                  );
                  if (!mounted) return;
                  _schedNameCtrl.clear();
                  setState(() {});
                },
          child: const Text('Save Template'),
        ),
        const SizedBox(height: 24),
        const Text('Scheduled templates', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...chores.defaultChores.map((dc) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: MemberAvatar(member: dc.assignedTo, radius: 16),
              title: Text(dc.name),
              subtitle: Text(
                '${dc.assignedTo?.name ?? 'Unassigned'} · every ${dc.frequencyDays} days',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => chores.deleteDefaultChore(dc.id),
              ),
            )),
      ],
    );
  }
}

class _MemberDropdown extends StatelessWidget {
  final String label;
  final List<Member> members;
  final Member? value;
  final ValueChanged<Member?> onChanged;

  const _MemberDropdown({
    required this.label,
    required this.members,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Member>(
      // ignore: deprecated_member_use
      value: value,
      decoration: InputDecoration(labelText: label),
      items: members
          .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
