import 'package:flutter/material.dart';

Color avatarColorFromName(String name) {
  final hue = name.codeUnits.fold(0, (sum, c) => sum + c) % 360;
  return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.6, 0.5).toColor();
}

String initialsFromName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}
