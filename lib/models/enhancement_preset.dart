import 'package:flutter/material.dart';

class EnhancementPreset {
  const EnhancementPreset({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
}
