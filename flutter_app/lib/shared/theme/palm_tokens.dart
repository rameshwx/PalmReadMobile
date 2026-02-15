import 'package:flutter/material.dart';

class PalmTokens {
  static const Color primary = Color(0xFF13ECA4);
  static const Color primaryDark = Color(0xFF0FB880);

  static const Color background = Color(0xFFF6F8F7);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textMain = Color(0xFF1E293B);
  static const Color textSub = Color(0xFF64748B);

  static const Color neutralDark = Color(0xFF10221C);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color purple = Color(0xFFA855F7);

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;

  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Color(0x2626D7A4),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}
