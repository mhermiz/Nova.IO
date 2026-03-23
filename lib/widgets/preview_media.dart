import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FilteredPreviewMedia extends StatelessWidget {
  const FilteredPreviewMedia({
    super.key,
    required this.controller,
    required this.showAfter,
    required this.adjustmentMatrix,
    required this.selectedPresetIndex,
    required this.presetStrength,
  });

  final VideoPlayerController controller;
  final bool showAfter;
  final List<double> adjustmentMatrix;
  final int selectedPresetIndex;
  final double presetStrength;

  @override
  Widget build(BuildContext context) {
    final video = VideoPlayer(controller);
    if (!showAfter) {
      return video;
    }

    final gradedVideo = ColorFiltered(
      colorFilter: ColorFilter.matrix(adjustmentMatrix),
      child: video,
    );

    return SkinToneProtection(
      selectedPresetIndex: selectedPresetIndex,
      presetStrength: presetStrength,
      child: TextureTreatment(
        selectedPresetIndex: selectedPresetIndex,
        presetStrength: presetStrength,
        child: gradedVideo,
      ),
    );
  }
}

class TextureTreatment extends StatelessWidget {
  const TextureTreatment({
    super.key,
    required this.child,
    required this.selectedPresetIndex,
    required this.presetStrength,
  });

  final Widget child;
  final int selectedPresetIndex;
  final double presetStrength;

  @override
  Widget build(BuildContext context) {
    return switch (selectedPresetIndex) {
      1 => Stack(
          fit: StackFit.expand,
          children: [
            child,
            Opacity(
              opacity: 0.10 * presetStrength,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 1.8 * presetStrength,
                  sigmaY: 1.8 * presetStrength,
                ),
                child: child,
              ),
            ),
          ],
        ),
      2 => Stack(
          fit: StackFit.expand,
          children: [
            child,
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.045 * presetStrength),
                ),
              ),
            ),
          ],
        ),
      3 => Stack(
          fit: StackFit.expand,
          children: [
            child,
            Opacity(
              opacity: 0.08 * presetStrength,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 1.1 * presetStrength,
                  sigmaY: 1.1 * presetStrength,
                ),
                child: child,
              ),
            ),
          ],
        ),
      _ => child,
    };
  }
}

class SkinToneProtection extends StatelessWidget {
  const SkinToneProtection({
    super.key,
    required this.child,
    required this.selectedPresetIndex,
    required this.presetStrength,
  });

  final Widget child;
  final int selectedPresetIndex;
  final double presetStrength;

  @override
  Widget build(BuildContext context) {
    final strength = switch (selectedPresetIndex) {
      1 => 0.10 * presetStrength,
      2 => 0.08 * presetStrength,
      3 => 0.09 * presetStrength,
      _ => 0.04 * presetStrength,
    };

    if (selectedPresetIndex < 0 || strength <= 0) {
      return child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: Align(
            alignment: const Alignment(0, -0.08),
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFC39E).withValues(alpha: strength),
                    const Color(0xFFF3B08A).withValues(alpha: strength * 0.45),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.36, 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
