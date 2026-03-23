import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/demo_clip.dart';

enum SceneFlavor {
  neutral,
  portrait,
  nature,
  water,
  night,
  urban,
  animation,
  socialEdit,
}

class FrameAnalysisStats {
  const FrameAnalysisStats({
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.warmth,
    required this.darkRatio,
    required this.highlightRatio,
  });

  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;
  final double darkRatio;
  final double highlightRatio;
}

class AnalysisRecommendation {
  const AnalysisRecommendation({
    required this.presetIndex,
    required this.confidence,
    required this.summary,
    required this.signals,
  });

  final int presetIndex;
  final int confidence;
  final String summary;
  final List<String> signals;
}

class AnalyzerHelper {
  static SceneFlavor sceneFlavorForClip(DemoClip clip) {
    final haystack = '${clip.title} ${clip.location} ${clip.tag}'.toLowerCase();

    if (haystack.contains('portrait') ||
        haystack.contains('face') ||
        haystack.contains('selfie') ||
        haystack.contains('person')) {
      return SceneFlavor.portrait;
    }
    if (haystack.contains('ocean') ||
        haystack.contains('beach') ||
        haystack.contains('sea') ||
        haystack.contains('water')) {
      return SceneFlavor.water;
    }
    if (haystack.contains('forest') ||
        haystack.contains('nature') ||
        haystack.contains('park') ||
        haystack.contains('foliage')) {
      return SceneFlavor.nature;
    }
    if (haystack.contains('night') ||
        haystack.contains('low light') ||
        haystack.contains('dark') ||
        haystack.contains('neon')) {
      return SceneFlavor.night;
    }
    if (haystack.contains('street') ||
        haystack.contains('city') ||
        haystack.contains('urban') ||
        haystack.contains('downtown')) {
      return SceneFlavor.urban;
    }
    if (haystack.contains('animation') ||
        haystack.contains('anime') ||
        haystack.contains('cartoon') ||
        haystack.contains('motion graphic')) {
      return SceneFlavor.animation;
    }
    if (haystack.contains('tiktok') ||
        haystack.contains('edit') ||
        haystack.contains('social') ||
        haystack.contains('reel') ||
        haystack.contains('shorts')) {
      return SceneFlavor.socialEdit;
    }
    return SceneFlavor.neutral;
  }

  static String sceneFlavorLabel(SceneFlavor flavor) {
    return switch (flavor) {
      SceneFlavor.neutral => 'Neutral',
      SceneFlavor.portrait => 'Portrait',
      SceneFlavor.nature => 'Nature',
      SceneFlavor.water => 'Water',
      SceneFlavor.night => 'Night',
      SceneFlavor.urban => 'Urban',
      SceneFlavor.animation => 'Animation',
      SceneFlavor.socialEdit => 'Social Edit',
    };
  }

  // Recommends a preset by combining sampled frame statistics with lighter scene/title hints.
  //
  // The scorer works like a simple weighted voting system:
  // - each preset starts at 0
  // - scene type adds a soft prior so auto/manual scene context can gently bias the result
  // - sampled frame metrics add the strongest votes because they come from actual image data
  // - title keywords only act as a fallback nudge when the filename clearly signals intent
  // - the preset with the highest total wins
  //
  // Score slots map to presets in this order:
  // 0 = Balanced
  // 1 = Cinematic
  // 2 = Vivid
  // 3 = Low-Light Rescue
  static AnalysisRecommendation analyzeRecommendation({
    required DemoClip clip,
    required SceneFlavor scene,
    required FrameAnalysisStats? frameStats,
    required List<String> presetTitles,
  }) {
    final title = clip.title.toLowerCase();
    final scores = [0, 0, 0, 0];

    switch (scene) {
      case SceneFlavor.portrait:
        scores[0] += 2;
        scores[1] += 1;
      case SceneFlavor.water:
      case SceneFlavor.nature:
        scores[2] += 2;
        scores[0] += 1;
      case SceneFlavor.night:
        scores[3] += 2;
        scores[1] += 2;
      case SceneFlavor.urban:
        scores[1] += 2;
        scores[2] += 1;
      case SceneFlavor.animation:
      case SceneFlavor.socialEdit:
        scores[2] += 2;
        scores[1] += 1;
        scores[0] += 1;
      case SceneFlavor.neutral:
        scores[0] += 1;
    }

    if (frameStats != null) {
      if (frameStats.darkRatio >= 0.34 || frameStats.brightness <= 0.40) {
        scores[3] += 4;
      }
      if (frameStats.highlightRatio >= 0.18) {
        scores[0] += 2;
        scores[3] += 1;
      }
      if (frameStats.saturation >= 0.36) {
        scores[2] += 4;
      } else if (frameStats.saturation <= 0.20) {
        scores[0] += 2;
      }
      if (frameStats.contrast >= 0.24) {
        scores[1] += 3;
        scores[2] += 1;
      } else if (frameStats.contrast <= 0.16) {
        scores[0] += 2;
        scores[3] += 1;
      }
      if (frameStats.warmth >= 0.05) {
        scores[1] += 2;
        scores[0] += 1;
      } else if (frameStats.warmth <= -0.04) {
        scores[2] += 2;
        scores[3] += 1;
      }
    }

    if (title.contains('edit') ||
        title.contains('tiktok') ||
        title.contains('reel') ||
        title.contains('anime') ||
        title.contains('music')) {
      scores[2] += 2;
    }

    if (title.contains('night') ||
        title.contains('dark') ||
        title.contains('low')) {
      scores[3] += 2;
    }

    if (title.contains('cinema') ||
        title.contains('film') ||
        title.contains('drive') ||
        title.contains('city')) {
      scores[1] += 2;
    }

    if (title.contains('portrait') || title.contains('face')) {
      scores[0] += 2;
    }

    var presetIndex = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[presetIndex]) {
        presetIndex = i;
      }
    }

    final sorted = [...scores]..sort();
    final margin = sorted.last - sorted[sorted.length - 2];
    final confidenceFloor = frameStats == null ? 66 : 76;
    final confidenceCeiling = frameStats == null ? 90 : 97;
    final confidence =
        (confidenceFloor + (margin * 5)).clamp(confidenceFloor, confidenceCeiling);

    final summary = switch (presetIndex) {
      0 =>
        'Balanced is recommended because the sampled frames look relatively controlled and natural, so a clean corrective pass should preserve detail best.',
      1 =>
        'Cinematic is recommended because the sampled frames show stronger contrast or warmth, which suits a more dramatic, filmic treatment.',
      2 =>
        'Vivid is recommended because the sampled frames already carry color energy, so extra pop and crispness should read well.',
      _ =>
        'Low-Light Rescue is recommended because the sampled frames skew darker or shadow-heavier, so a more protective lift should hold detail better.',
    };

    final strongestSignal = switch (scene) {
      SceneFlavor.neutral => 'Auto scene detection is inconclusive',
      _ => 'Detected scene: ${sceneFlavorLabel(scene)}',
    };

    final signals = frameStats == null
        ? <String>[
            strongestSignal,
            'Frame sampling unavailable, using clip metadata fallback',
            'Recommended look: ${presetTitles[presetIndex]}',
          ]
        : <String>[
            strongestSignal,
            '5 frames sampled: B${(frameStats.brightness * 100).round()} C${(frameStats.contrast * 100).round()} S${(frameStats.saturation * 100).round()}',
            'Shadow load ${(frameStats.darkRatio * 100).round()}% • Highlights ${(frameStats.highlightRatio * 100).round()}%',
            'Recommended look: ${presetTitles[presetIndex]}',
          ];

    return AnalysisRecommendation(
      presetIndex: presetIndex,
      confidence: confidence,
      summary: summary,
      signals: signals,
    );
  }

  static List<int> buildAnalysisSampleTimes(int durationMs, {required int seed}) {
    final safeDurationMs = durationMs < 1500 ? 1500 : durationMs;
    final startMs = (safeDurationMs * 0.08).round();
    final endMs = (safeDurationMs * 0.92).round();
    final rangeMs = (endMs - startMs) < 1 ? 1 : (endMs - startMs);

    final values = <int>[];
    var state = seed == 0 ? 1 : seed;
    for (var index = 0; index < 5; index++) {
      final bucketStart = startMs + ((rangeMs * index) ~/ 5);
      final bucketEnd = startMs + ((rangeMs * (index + 1)) ~/ 5);
      final bucketWidth = (bucketEnd - bucketStart) < 1 ? 1 : (bucketEnd - bucketStart);
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      values.add(bucketStart + (state % bucketWidth));
    }
    return values;
  }

  static Future<FrameAnalysisStats?> analyzeVideoFrames({
    required String filePath,
    required int durationMs,
    required int seed,
  }) async {
    if (filePath.isEmpty) {
      return null;
    }

    final sampleTimes = buildAnalysisSampleTimes(
      durationMs > 0 ? durationMs : 6000,
      seed: seed,
    );

    final samples = <FrameAnalysisStats>[];
    for (final timeMs in sampleTimes) {
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: filePath,
        imageFormat: ImageFormat.PNG,
        timeMs: timeMs,
        quality: 45,
        maxWidth: 144,
      );
      if (thumbnailBytes == null) {
        continue;
      }

      final stats = await analyzeImageBytes(thumbnailBytes);
      if (stats != null) {
        samples.add(stats);
      }
    }

    if (samples.isEmpty) {
      return null;
    }

    double average(double Function(FrameAnalysisStats sample) valueOf) {
      final total = samples.fold<double>(
        0,
        (sum, sample) => sum + valueOf(sample),
      );
      return total / samples.length;
    }

    return FrameAnalysisStats(
      brightness: average((sample) => sample.brightness),
      contrast: average((sample) => sample.contrast),
      saturation: average((sample) => sample.saturation),
      warmth: average((sample) => sample.warmth),
      darkRatio: average((sample) => sample.darkRatio),
      highlightRatio: average((sample) => sample.highlightRatio),
    );
  }

  static Future<FrameAnalysisStats?> analyzeImageBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        return null;
      }

      final pixels = byteData.buffer.asUint8List();
      var pixelCount = 0;
      var luminanceSum = 0.0;
      var luminanceSquaredSum = 0.0;
      var saturationSum = 0.0;
      var warmthSum = 0.0;
      var darkPixels = 0;
      var highlightPixels = 0;

      for (var i = 0; i <= pixels.length - 4; i += 16) {
        final red = pixels[i] / 255;
        final green = pixels[i + 1] / 255;
        final blue = pixels[i + 2] / 255;
        final alpha = pixels[i + 3] / 255;

        if (alpha < 0.1) {
          continue;
        }

        final maxChannel = [red, green, blue].reduce((a, b) => a > b ? a : b);
        final minChannel = [red, green, blue].reduce((a, b) => a < b ? a : b);
        final luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
        final saturation =
            maxChannel == 0 ? 0.0 : (maxChannel - minChannel) / maxChannel;
        final warmth = ((red - blue) + ((red - green) * 0.35)).clamp(-1.0, 1.0);

        pixelCount++;
        luminanceSum += luminance;
        luminanceSquaredSum += luminance * luminance;
        saturationSum += saturation;
        warmthSum += warmth;
        if (luminance <= 0.18) {
          darkPixels++;
        }
        if (luminance >= 0.82) {
          highlightPixels++;
        }
      }

      if (pixelCount == 0) {
        return null;
      }

      final brightness = luminanceSum / pixelCount;
      final variance = (luminanceSquaredSum / pixelCount) - (brightness * brightness);
      final safeVariance = variance < 0 ? 0.0 : variance;

      return FrameAnalysisStats(
        brightness: brightness,
        contrast: safeVariance <= 0 ? 0.0 : math.sqrt(safeVariance),
        saturation: saturationSum / pixelCount,
        warmth: warmthSum / pixelCount,
        darkRatio: darkPixels / pixelCount,
        highlightRatio: highlightPixels / pixelCount,
      );
    } finally {
      image.dispose();
      codec.dispose();
    }
  }
}
