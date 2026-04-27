class Member {
  final String id;
  final String name;
  final String color;
  final String householdId;

  const Member({
    required this.id,
    required this.name,
    required this.color,
    required this.householdId,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as String,
        householdId: json['household'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color, 'household': householdId};

  @override
  bool operator ==(Object other) => other is Member && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
