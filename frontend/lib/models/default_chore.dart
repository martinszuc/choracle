import 'member.dart';

class DefaultChore {
  final String id;
  final String name;
  final Member? assignedTo;
  final int frequencyDays;
  final DateTime startDate;
  final DateTime? lastGenerated;

  const DefaultChore({
    required this.id,
    required this.name,
    this.assignedTo,
    required this.frequencyDays,
    required this.startDate,
    this.lastGenerated,
  });

  factory DefaultChore.fromJson(Map<String, dynamic> json) => DefaultChore(
        id: json['id'] as String,
        name: json['name'] as String,
        assignedTo: json['assigned_to'] != null
            ? Member.fromJson(json['assigned_to'] as Map<String, dynamic>)
            : null,
        frequencyDays: json['frequency_days'] as int,
        startDate: DateTime.parse(json['start_date'] as String),
        lastGenerated: json['last_generated'] != null
            ? DateTime.parse(json['last_generated'] as String)
            : null,
      );
}
