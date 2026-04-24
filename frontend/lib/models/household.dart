import 'member.dart';

class Household {
  final String id;
  final String name;
  final List<Member> members;

  const Household({required this.id, required this.name, required this.members});

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        id: json['id'] as String,
        name: json['name'] as String,
        members: (json['members'] as List<dynamic>)
            .map((m) => Member.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}
