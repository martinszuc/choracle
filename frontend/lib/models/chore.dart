import 'member.dart';

class Chore {
  final String id;
  final String name;
  final Member? assignedTo;
  final Member? originalAssignedTo;
  final bool completed;
  final Member? completedBy;
  final DateTime? completedAt;
  final String weekIdentifier;
  final DateTime createdAt;

  const Chore({
    required this.id,
    required this.name,
    this.assignedTo,
    this.originalAssignedTo,
    required this.completed,
    this.completedBy,
    this.completedAt,
    required this.weekIdentifier,
    required this.createdAt,
  });

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
        id: json['id'] as String,
        name: json['name'] as String,
        assignedTo: json['assigned_to'] != null
            ? Member.fromJson(json['assigned_to'] as Map<String, dynamic>)
            : null,
        originalAssignedTo: json['original_assigned_to'] != null
            ? Member.fromJson(json['original_assigned_to'] as Map<String, dynamic>)
            : null,
        completed: json['completed'] as bool,
        completedBy: json['completed_by'] != null
            ? Member.fromJson(json['completed_by'] as Map<String, dynamic>)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        weekIdentifier: json['week_identifier'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
