import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewCard extends StatelessWidget {
  const VideoPreviewCard({
    super.key,
    this.cardKey,
    required this.subtitle,
    required this.showAfter,
    required this.onToggleBeforeAfter,
    required this.viewport,
  });

  final Key? cardKey;
  final String subtitle;
  final bool showAfter;
  final ValueChanged<bool> onToggleBeforeAfter;
  final Widget viewport;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: cardKey,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('Before')),
                    ButtonSegment<bool>(value: true, label: Text('After')),
                  ],
                  selected: {showAfter},
                  onSelectionChanged: (selection) {
                    onToggleBeforeAfter(selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            viewport,
          ],
        ),
      ),
    );
  }
}

class PlaybackTimelineOverlay extends StatelessWidget {
  const PlaybackTimelineOverlay({
    super.key,
    required this.controller,
  });

  final VideoPlayerController controller;

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final totalMs = math.max(value.duration.inMilliseconds, 1);
        final currentMs = value.position.inMilliseconds.clamp(0, totalMs);

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.24),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: currentMs.toDouble(),
                  min: 0,
                  max: totalMs.toDouble(),
                  onChanged: (nextValue) {
                    controller.seekTo(Duration(milliseconds: nextValue.round()));
                  },
                ),
              ),
              Row(
                children: [
                  Text(
                    _formatDuration(Duration(milliseconds: currentMs)),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(value.duration),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
