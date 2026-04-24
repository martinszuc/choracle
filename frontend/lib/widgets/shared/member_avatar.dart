import 'package:flutter/material.dart';
import '../../core/utils/avatar.dart';
import '../../models/member.dart';

class MemberAvatar extends StatelessWidget {
  final Member? member;
  final String? name;
  final String? color;
  final double radius;

  const MemberAvatar({super.key, this.member, this.name, this.color, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final displayName = member?.name ?? name ?? '?';
    final displayColor = _parseColor(member?.color ?? color);
    return CircleAvatar(
      radius: radius,
      backgroundColor: displayColor,
      child: Text(
        initialsFromName(displayName),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _parseColor(String? raw) {
    if (raw == null) return Colors.grey;
    if (raw.startsWith('#')) {
      final hex = raw.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (raw.startsWith('hsl')) {
      final parts = RegExp(r'hsl\((\d+),(\d+)%,(\d+)%\)').firstMatch(raw);
      if (parts != null) {
        return HSLColor.fromAHSL(
          1.0,
          double.parse(parts.group(1)!),
          double.parse(parts.group(2)!) / 100,
          double.parse(parts.group(3)!) / 100,
        ).toColor();
      }
    }
    return avatarColorFromName(raw);
  }
}
