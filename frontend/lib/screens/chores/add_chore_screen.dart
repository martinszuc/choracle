import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/member.dart';
import '../../providers/app_provider.dart';
import '../../providers/chores_provider.dart';

class AddChoreScreen extends StatefulWidget {
  const AddChoreScreen({super.key});

  @override
  State<AddChoreScreen> createState() => _AddChoreScreenState();
}

class _AddChoreScreenState extends State<AddChoreScreen> {
  int _tabIndex = 0;

  // immediate form state
  final _nameCtrl = TextEditingController();
  Member? _selectedMember;

  // scheduled form state
  final _schedNameCtrl = TextEditingController();
  final _freqCtrl = TextEditingController(text: '7');
  DateTime _startDate = DateTime.now();

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
                  : _buildScheduledForm(chores),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmediateForm(List<Member> members, ChoresProvider chores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Chore name')),
        const SizedBox(height: 12),
        DropdownButtonFormField<Member>(
          value: _selectedMember,
          hint: const Text('Assign to'),
          decoration: const InputDecoration(labelText: 'Assign to'),
          items: context.read<AppProvider>().members
              .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
              .toList(),
          onChanged: (m) => setState(() => _selectedMember = m),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty || _selectedMember == null) return;
            await chores.addChore(name, _selectedMember!.id);
            if (!mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Add Chore'),
        ),
      ],
    );
  }

  Widget _buildScheduledForm(ChoresProvider chores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _schedNameCtrl, decoration: const InputDecoration(labelText: 'Chore name')),
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
          onPressed: () async {
            final name = _schedNameCtrl.text.trim();
            final freq = int.tryParse(_freqCtrl.text) ?? 7;
            if (name.isEmpty) return;
            await chores.addDefaultChore(name, freq, _startDate);
            if (!mounted) return;
            _schedNameCtrl.clear();
          },
          child: const Text('Save Template'),
        ),
        const SizedBox(height: 24),
        const Text('Scheduled templates', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...chores.defaultChores.map((dc) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(dc.name),
              subtitle: Text('Every ${dc.frequencyDays} days'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => chores.deleteDefaultChore(dc.id),
              ),
            )),
      ],
    );
  }
}
