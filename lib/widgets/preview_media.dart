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

    return gradedVideo;
  }
}
