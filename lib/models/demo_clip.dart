import 'package:flutter/material.dart';

class DemoClip {
  const DemoClip({
    required this.title,
    required this.location,
    required this.duration,
    required this.accent,
    required this.tag,
    this.filePath,
  });

  final String title;
  final String location;
  final String duration;
  final Color accent;
  final String tag;
  final String? filePath;

  DemoClip copyWith({
    String? title,
    String? location,
    String? duration,
    Color? accent,
    String? tag,
    String? filePath,
  }) {
    return DemoClip(
      title: title ?? this.title,
      location: location ?? this.location,
      duration: duration ?? this.duration,
      accent: accent ?? this.accent,
      tag: tag ?? this.tag,
      filePath: filePath ?? this.filePath,
    );
  }
}
