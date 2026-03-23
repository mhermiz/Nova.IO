import 'dart:math' as math;
import 'dart:typed_data';
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

class VideoPreviewViewport extends StatelessWidget {
  const VideoPreviewViewport({
    super.key,
    required this.aspectRatio,
    required this.backgroundColors,
    required this.media,
    required this.effectOverlays,
    required this.isPreviewLoading,
    this.onBackgroundTap,
    this.topLeftBadge,
    this.centerControl,
    this.bottomOverlay,
  });

  final double aspectRatio;
  final List<Color> backgroundColors;
  final Widget media;
  final List<Widget> effectOverlays;
  final bool isPreviewLoading;
  final VoidCallback? onBackgroundTap;
  final Widget? topLeftBadge;
  final Widget? centerControl;
  final Widget? bottomOverlay;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: backgroundColors,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              media,
              ...effectOverlays,
              if (onBackgroundTap != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBackgroundTap,
                  ),
                ),
              if (isPreviewLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.32),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (topLeftBadge != null)
                Positioned(
                  top: 18,
                  left: 18,
                  child: topLeftBadge!,
                ),
              if (centerControl != null) Center(child: centerControl!),
              if (bottomOverlay != null)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: bottomOverlay!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyPreviewMessage extends StatelessWidget {
  const EmptyPreviewMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: const Text(
        'No imported video yet.\nUse Import Video to add one to the queue.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          height: 1.5,
          fontSize: 16,
        ),
      ),
    );
  }
}

class PreviewStatusBadge extends StatelessWidget {
  const PreviewStatusBadge({
    super.key,
    required this.label,
    required this.visible,
  });

  final String label;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: visible ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class PreviewPlaybackButton extends StatelessWidget {
  const PreviewPlaybackButton({
    super.key,
    required this.visible,
    required this.isPlaying,
    required this.onTap,
  });

  final bool visible;
  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: visible ? 1 : 0,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 42,
            ),
          ),
        ),
      ),
    );
  }
}

class MiniPreviewCard extends StatelessWidget {
  const MiniPreviewCard({
    super.key,
    required this.title,
    required this.media,
    required this.onTap,
  });

  final String title;
  final Widget media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const shellRadius = Radius.circular(22);

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.all(shellRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(shellRadius),
        child: Ink(
          width: 184,
          decoration: BoxDecoration(
            color: const Color(0xFF101A2B).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.all(shellRadius),
            border: Border.all(color: const Color(0xFF2A3C5E)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 96,
                    width: double.infinity,
                    child: media,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to return to preview',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MiniPreviewFallback extends StatelessWidget {
  const MiniPreviewFallback({
    super.key,
    this.thumbnailBytes,
    this.accentColor,
  });

  final Uint8List? thumbnailBytes;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    if (thumbnailBytes != null) {
      return Image.memory(
        thumbnailBytes!,
        fit: BoxFit.cover,
      );
    }

    if (accentColor == null) {
      return Container(
        color: const Color(0xFF13213A),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor!.withValues(alpha: 0.55),
            const Color(0xFF101B2D),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.video_collection_rounded, size: 28),
      ),
    );
  }
}
