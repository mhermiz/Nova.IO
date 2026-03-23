import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'widgets/video_preview_card.dart';

// TODO: Refactor main.dart and split models/UI sections into different files to maintain readability
void main() {
  runApp(const VideoEnhancerApp());
}

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

class VideoEnhancerApp extends StatelessWidget {
  const VideoEnhancerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF1F7AE0);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Enhancer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF09111F),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF121D31),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Color(0xFF22324D)),
          ),
        ),
      ),
      home: const VideoEnhancerHomePage(),
    );
  }
}

class VideoEnhancerHomePage extends StatefulWidget {
  const VideoEnhancerHomePage({super.key});

  @override
  State<VideoEnhancerHomePage> createState() => _VideoEnhancerHomePageState();
}

class _VideoEnhancerHomePageState extends State<VideoEnhancerHomePage> {
  final List<DemoClip> _clips = [];
  final GlobalKey _previewSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  final List<EnhancementPreset> _presets = const [
    EnhancementPreset(
      title: 'Balanced',
      subtitle: 'Neutral cleanup with natural detail',
      accent: Color(0xFF63B3FF),
      icon: Icons.tune_rounded,
    ),
    EnhancementPreset(
      title: 'Cinematic',
      subtitle: 'Deeper contrast and dramatic color shaping',
      accent: Color(0xFFFF9B71),
      icon: Icons.movie_filter_rounded,
    ),
    EnhancementPreset(
      title: 'Vivid',
      subtitle: 'Punchier saturation for social clips',
      accent: Color(0xFF68E0C1),
      icon: Icons.auto_awesome_rounded,
    ),
    EnhancementPreset(
      title: 'Low-Light Rescue',
      subtitle: 'Lifts shadows and protects highlights',
      accent: Color(0xFFD7A5FF),
      icon: Icons.nightlight_round,
    ),
  ];

  int _selectedClipIndex = 0;
  int _selectedPresetIndex = -1;
  bool _showAfter = true;
  bool _isAnalyzing = false;
  double _brightness = 54;
  double _contrast = 61;
  double _saturation = 58;
  double _warmth = 46;
  double _tint = 50;
  double _highlights = 52;
  double _shadows = 48;
  double _presetStrength = 0.85;
  SceneFlavor? _sceneOverride;
  VideoPlayerController? _videoController;
  bool _isPreviewLoading = false;
  final Map<String, Uint8List> _clipThumbnails = {};
  bool _showPreviewJumpButton = false;
  bool _showPreviewControls = true;
  int? _analysisRecommendedPresetIndex;
  int _analysisConfidence = 0;
  String _analysisSummary =
      'Run analysis to get a smarter preset recommendation for the selected clip.';
  List<String> _analysisSignals = const [
    'Scene detection idle',
    'Tonal profile pending',
    'Preset recommendation pending',
  ];

  DemoClip? get _selectedClip =>
      _clips.isEmpty ? null : _clips[_selectedClipIndex];
  EnhancementPreset? get _selectedPreset =>
      _selectedPresetIndex >= 0 ? _presets[_selectedPresetIndex] : null;
  SceneFlavor get _currentSceneFlavor {
    if (_sceneOverride != null) {
      return _sceneOverride!;
    }
    final clip = _selectedClip;
    if (clip == null) {
      return SceneFlavor.neutral;
    }
    return _sceneFlavorForClip(clip);
  }

  @override
  // Sets up scroll-driven UI state and loads a preview controller if a clip exists.
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
    _syncPreviewController();
  }

  @override
  // Cleans up controllers created for scrolling and video playback.
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // Generates a demo quality score from the current tuning state for the summary UI.
  int get _qualityScore {
    final weightedScore =
        (_brightness * 0.21) +
        (_contrast * 0.29) +
        (_saturation * 0.25) +
        (_warmth * 0.15) +
        (((_selectedPresetIndex + 1).clamp(0, _presets.length)) * 2.7) +
        ((_selectedClipIndex + 1) * 1.8);
    return weightedScore.clamp(0, 100).round();
  }

  // Infers a scene category from lightweight clip metadata when no manual override is set.
  SceneFlavor _sceneFlavorForClip(DemoClip clip) {
    final haystack =
        '${clip.title} ${clip.location} ${clip.tag}'.toLowerCase();

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

  // Converts internal scene enum values into user-facing labels.
  String _sceneFlavorLabel(SceneFlavor flavor) {
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

  // Stores the user's explicit scene override choice, or returns to auto mode with null.
  void _setSceneOverride(SceneFlavor? flavor) {
    setState(() {
      _sceneOverride = flavor;
    });
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
  Future<({
    int presetIndex,
    int confidence,
    String summary,
    List<String> signals,
  })> _analyzeClipRecommendation(DemoClip clip) async {
    final scene = _currentSceneFlavor;
    final title = clip.title.toLowerCase();
    final frameStats = await _analyzeVideoFrames(clip);

    // One running score per preset. Higher means the clip characteristics match that look better.
    final scores = [0, 0, 0, 0];

    // Scene type acts as a low-strength prior rather than a hard rule.
    // This helps the analyzer start in the right neighborhood without forcing a preset.
    //
    // Examples:
    // - portrait clips slightly prefer Balanced because it is the safest natural look
    // - night clips lean toward Low-Light Rescue and Cinematic
    // - animation/social edits lean toward Vivid because those clips usually tolerate stronger stylizing
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
      // Frame stats are the most important part of the recommendation.
      // They come from five sampled frames and describe how the video actually looks on average.
      //
      // The thresholds below are tuned to create clear preset personalities:
      // - dark / shadow-heavy footage strongly favors Low-Light Rescue
      // - colorful footage strongly favors Vivid
      // - high-contrast or warm footage leans Cinematic
      // - flatter, restrained footage tends to favor Balanced
      if (frameStats.darkRatio >= 0.34 || frameStats.brightness <= 0.40) {
        // A large dark-pixel share usually means underexposed or shadow-heavy footage.
        // Low-Light Rescue is designed to lift and protect that kind of material.
        scores[3] += 4;
      }
      if (frameStats.highlightRatio >= 0.18) {
        // Lots of bright pixels can mean highlight pressure.
        // Balanced gets a boost for safer cleanup, while Low-Light Rescue gets a smaller
        // boost because its protective tone shaping can also help preserve bright areas.
        scores[0] += 2;
        scores[3] += 1;
      }
      if (frameStats.saturation >= 0.36) {
        // Already-colorful footage usually benefits from Vivid's punchier identity.
        scores[2] += 4;
      } else if (frameStats.saturation <= 0.20) {
        // Muted footage is often better served by a controlled corrective look first.
        scores[0] += 2;
      }
      if (frameStats.contrast >= 0.24) {
        // Strong contrast aligns well with Cinematic, with a small spillover toward Vivid.
        scores[1] += 3;
        scores[2] += 1;
      } else if (frameStats.contrast <= 0.16) {
        // Lower-contrast footage can read as flatter or softer, which tends to fit either
        // a neutral cleanup pass or a shadow-recovery pass.
        scores[0] += 2;
        scores[3] += 1;
      }
      if (frameStats.warmth >= 0.05) {
        // Warmer footage is a natural fit for Cinematic's highlight shaping and overall tone.
        scores[1] += 2;
        scores[0] += 1;
      } else if (frameStats.warmth <= -0.04) {
        // Cooler footage often pairs better with Vivid's fresher color energy, with a small
        // allowance for Low-Light Rescue when cool tones come from darker environments.
        scores[2] += 2;
        scores[3] += 1;
      }
    }

    // Filename cues are intentionally weak. They should help when obvious, but never dominate
    // actual frame analysis from the imported video.
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

    // Pick the preset with the highest accumulated score.
    var presetIndex = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[presetIndex]) {
        presetIndex = i;
      }
    }

    // Confidence is based on separation between the best and second-best scores.
    // A narrow margin means the clip could plausibly fit more than one look, while
    // a wide margin means one preset clearly stood out from the others.
    final sorted = [...scores]..sort();
    final margin = sorted.last - sorted[sorted.length - 2];
    final confidenceFloor = frameStats == null ? 66 : 76;
    final confidenceCeiling = frameStats == null ? 90 : 97;
    final confidence =
        (confidenceFloor + (margin * 5)).clamp(confidenceFloor, confidenceCeiling);

    // The user-facing summary explains the winning preset in plain language.
    final summary = switch (presetIndex) {
      0 => 'Balanced is recommended because the sampled frames look relatively controlled and natural, so a clean corrective pass should preserve detail best.',
      1 => 'Cinematic is recommended because the sampled frames show stronger contrast or warmth, which suits a more dramatic, filmic treatment.',
      2 => 'Vivid is recommended because the sampled frames already carry color energy, so extra pop and crispness should read well.',
      _ => 'Low-Light Rescue is recommended because the sampled frames skew darker or shadow-heavier, so a more protective lift should hold detail better.',
    };

    final strongestSignal = switch (scene) {
      SceneFlavor.neutral => 'Auto scene detection is inconclusive',
      _ => 'Detected scene: ${_sceneFlavorLabel(scene)}',
    };

    // These insight pills expose the strongest signals that led to the recommendation.
    final signals = frameStats == null
        ? <String>[
            strongestSignal,
            'Frame sampling unavailable, using clip metadata fallback',
            'Recommended look: ${_presets[presetIndex].title}',
          ]
        : <String>[
            strongestSignal,
            '5 frames sampled: B${(frameStats.brightness * 100).round()} C${(frameStats.contrast * 100).round()} S${(frameStats.saturation * 100).round()}',
            'Shadow load ${(frameStats.darkRatio * 100).round()}% • Highlights ${(frameStats.highlightRatio * 100).round()}%',
            'Recommended look: ${_presets[presetIndex].title}',
          ];

    return (
      presetIndex: presetIndex,
      confidence: confidence,
      summary: summary,
      signals: signals,
    );
  }

  // Samples multiple points in the video and averages their image statistics into one profile.
  Future<_FrameAnalysisStats?> _analyzeVideoFrames(DemoClip clip) async {
    final filePath = clip.filePath;
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    final durationMs = _selectedClip?.filePath == filePath &&
            _videoController?.value.isInitialized == true
        ? _videoController!.value.duration.inMilliseconds
        : 0;
    final sampleTimes = _buildAnalysisSampleTimes(
      durationMs > 0 ? durationMs : 6000,
      seed: filePath.hashCode ^ clip.title.hashCode,
    );

    final samples = <_FrameAnalysisStats>[];
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
      final stats = await _analyzeImageBytes(thumbnailBytes);
      if (stats != null) {
        samples.add(stats);
      }
    }

    if (samples.isEmpty) {
      return null;
    }

    double average(double Function(_FrameAnalysisStats sample) valueOf) {
      final total = samples.fold<double>(
        0,
        (sum, sample) => sum + valueOf(sample),
      );
      return total / samples.length;
    }

    return _FrameAnalysisStats(
      brightness: average((sample) => sample.brightness),
      contrast: average((sample) => sample.contrast),
      saturation: average((sample) => sample.saturation),
      warmth: average((sample) => sample.warmth),
      darkRatio: average((sample) => sample.darkRatio),
      highlightRatio: average((sample) => sample.highlightRatio),
    );
  }

  // Picks five spread-out pseudo-random timestamps so analysis is less biased to one moment.
  List<int> _buildAnalysisSampleTimes(int durationMs, {required int seed}) {
    final safeDurationMs = math.max(durationMs, 1500);
    final startMs = (safeDurationMs * 0.08).round();
    final endMs = (safeDurationMs * 0.92).round();
    final rangeMs = math.max(endMs - startMs, 1);
    final random = math.Random(seed);

    return List.generate(5, (index) {
      final bucketStart = startMs + ((rangeMs * index) ~/ 5);
      final bucketEnd = startMs + ((rangeMs * (index + 1)) ~/ 5);
      final bucketWidth = math.max(bucketEnd - bucketStart, 1);
      return bucketStart + random.nextInt(bucketWidth);
    });
  }

  // Reads raw RGBA pixels from a generated frame and derives simple tone/color metrics.
  Future<_FrameAnalysisStats?> _analyzeImageBytes(Uint8List bytes) async {
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

        final maxChannel = math.max(red, math.max(green, blue));
        final minChannel = math.min(red, math.min(green, blue));
        final luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
        final saturation = maxChannel == 0
            ? 0.0
            : (maxChannel - minChannel) / maxChannel;
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
      final variance = math.max(
        (luminanceSquaredSum / pixelCount) - (brightness * brightness),
        0.0,
      );

      return _FrameAnalysisStats(
        brightness: brightness,
        contrast: math.sqrt(variance),
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

  // Clears the active preset without disturbing the current manual slider values.
  void _clearPreset() {
    setState(() {
      _selectedPresetIndex = -1;
    });
  }

  // Applies a preset by updating both visible sliders and hidden preset-strength defaults.
  void _applyPreset(int presetIndex) {
    final settings = switch (presetIndex) {
      0 => (brightness: 51.0, contrast: 61.0, saturation: 52.0, warmth: 50.0),
      1 => (brightness: 44.0, contrast: 78.0, saturation: 58.0, warmth: 61.0),
      2 => (brightness: 58.0, contrast: 72.0, saturation: 84.0, warmth: 48.0),
      _ => (brightness: 70.0, contrast: 48.0, saturation: 44.0, warmth: 57.0),
    };
    final colorBalance = switch (presetIndex) {
      0 => 50.0,
      1 => 55.0,
      2 => 46.0,
      _ => 52.0,
    };
    final tonal = switch (presetIndex) {
      0 => (highlights: 48.0, shadows: 50.0),
      1 => (highlights: 42.0, shadows: 40.0),
      2 => (highlights: 58.0, shadows: 52.0),
      _ => (highlights: 38.0, shadows: 72.0),
    };

    setState(() {
      _selectedPresetIndex = presetIndex;
      _brightness = settings.brightness;
      _contrast = settings.contrast;
      _saturation = settings.saturation;
      _warmth = settings.warmth;
      _tint = colorBalance;
      _highlights = tonal.highlights;
      _shadows = tonal.shadows;
      _presetStrength = 0.85;
    });
  }

  // Runs the analysis flow, updates the analysis card, and applies the recommended preset.
  Future<void> _runAiAnalysis() async {
    final selectedClip = _selectedClip;
    if (_isAnalyzing || selectedClip == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    final analysis = await _analyzeClipRecommendation(selectedClip);

    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      _analysisRecommendedPresetIndex = analysis.presetIndex;
      _analysisConfidence = analysis.confidence;
      _analysisSummary = analysis.summary;
      _analysisSignals = analysis.signals;
    });
    _applyPreset(analysis.presetIndex);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'AI Scene Analysis recommended "${_presets[analysis.presetIndex].title}" for ${selectedClip.title}.',
        ),
      ),
    );
  }

  // Imports device videos into the queue, then prepares thumbnails and preview playback.
  Future<void> _importVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final importedClips = result.files.map(_buildImportedClip).toList();

    setState(() {
      _clips.addAll(importedClips);
      _selectedClipIndex = _clips.length - importedClips.length;
      _sceneOverride = null;
    });

    _generateThumbnails(importedClips);
    await _syncPreviewController();

    if (!mounted) {
      return;
    }

    final clipLabel = importedClips.length == 1 ? 'video' : 'videos';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imported ${importedClips.length} $clipLabel into the queue.'),
      ),
    );
  }

  // Temporary export action until a real render pipeline is wired in.
  void _showExportMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Export Enhanced Video is a placeholder for the rendering pipeline.',
        ),
      ),
    );
  }

  // Smoothly scrolls back to the main preview from the mini-player shortcut.
  Future<void> _jumpToPreview() async {
    final previewContext = _previewSectionKey.currentContext;
    if (previewContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      previewContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  // Tracks when the main preview is mostly off-screen so the mini preview can appear.
  void _handleScroll() {
    final previewContext = _previewSectionKey.currentContext;
    if (previewContext == null) {
      return;
    }

    final renderBox = previewContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }

    final topOffset = renderBox.localToGlobal(Offset.zero).dy;
    final shouldShowButton = topOffset < -(renderBox.size.height * 0.5);

    if (shouldShowButton == _showPreviewJumpButton || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || shouldShowButton == _showPreviewJumpButton) {
        return;
      }

      setState(() {
        _showPreviewJumpButton = shouldShowButton;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 980;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1425),
              Color(0xFF09111F),
              Color(0xFF060A14),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroSection(context),
                        const SizedBox(height: 20),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _buildPreviewCard(context),
                                    const SizedBox(height: 20),
                                    _buildClipShelf(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildAnalysisCard(),
                                    const SizedBox(height: 20),
                                    _buildPresetCard(),
                                    const SizedBox(height: 20),
                                    _buildAdjustmentsCard(),
                                    const SizedBox(height: 20),
                                    _buildExportCard(),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _buildPreviewCard(context),
                          const SizedBox(height: 20),
                          _buildClipShelf(),
                          const SizedBox(height: 20),
                          _buildAnalysisCard(),
                          const SizedBox(height: 20),
                          _buildPresetCard(),
                          const SizedBox(height: 20),
                          _buildAdjustmentsCard(),
                          const SizedBox(height: 20),
                          _buildExportCard(),
                        ],
                        const SizedBox(height: 88),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showPreviewJumpButton && _selectedClip != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: _buildMiniPreviewOverlay(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final selectedClip = _selectedClip;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (selectedClip?.accent ?? const Color(0xFF4FA3FF)).withValues(
                alpha: 0.25,
              ),
              const Color(0xFF121D31),
              const Color(0xFF0C1424),
            ],
          ),
        ),
        child: Wrap(
          runSpacing: 20,
          spacing: 20,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Text('Realtime enhancement workspace'),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Import Pipeline',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Import your video below to add it to the import queue.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _importVideo,
                        icon: const Icon(Icons.add_to_photos_rounded),
                        label: const Text('Import Video'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _runAiAnalysis,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('AI Scene Analysis'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                children: [
                  _buildMetricTile(
                    'Active clip',
                    selectedClip?.title ?? 'No clip selected',
                  ),
                  const SizedBox(height: 12),
                  _buildMetricTile(
                    'Preset',
                    _selectedPreset?.title ?? 'No preset',
                  ),
                  const SizedBox(height: 12),
                  _buildMetricTile(
                    'Scene type',
                    _sceneOverride == null
                        ? 'Auto • ${_sceneFlavorLabel(_currentSceneFlavor)}'
                        : _sceneFlavorLabel(_currentSceneFlavor),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricTile('Quality score', '$_qualityScore / 100'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    final selectedClip = _selectedClip;
    return VideoPreviewCard(
      cardKey: _previewSectionKey,
      subtitle: selectedClip == null
          ? 'Import a video to start previewing'
          : '${selectedClip.location} • ${selectedClip.duration}',
      showAfter: _showAfter,
      onToggleBeforeAfter: (showAfter) {
        setState(() {
          _showAfter = showAfter;
        });
      },
      viewport: _buildPreviewViewport(),
    );
    // ignore: dead_code
    return Card(
      key: _previewSectionKey,
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selectedClip == null
                            ? 'Import a video to start previewing'
                            : '${selectedClip.location} • ${selectedClip.duration}',
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
                  selected: {_showAfter},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _showAfter = selection.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildPreviewViewport(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewViewport() {
    final selectedClip = _selectedClip;
    final controller = _videoController;
    final hasVideo = controller != null && controller.value.isInitialized;
    final showPlaybackControls = !hasVideo || _showPreviewControls;
    final hasSelectedClip = selectedClip != null;
    final showBalancedOverlay = _showAfter && _selectedPresetIndex == 0;
    final showCinematicOverlay = _showAfter && _selectedPresetIndex == 1;
    final showVividOverlay = _showAfter && _selectedPresetIndex == 2;
    final showLowLightOverlay = _showAfter && _selectedPresetIndex == 3;

    return AspectRatio(
      aspectRatio: hasVideo ? controller.value.aspectRatio : 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _showAfter
                ? [
                    (selectedClip?.accent ?? const Color(0xFF4FA3FF)).withValues(
                      alpha: 0.30,
                    ),
                    const Color(0xFF172842),
                    const Color(0xFF0A1423),
                  ]
                : [
                    const Color(0xFF3A4658),
                    const Color(0xFF202A38),
                    const Color(0xFF121823),
                  ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasVideo)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: _buildFilteredVideo(controller),
                  ),
                )
              else
                if (selectedClip != null)
                  CustomPaint(
                    painter: FramePainter(
                      accent: selectedClip.accent,
                      emphasizeEnhancement: _showAfter,
                    ),
                  )
                else
                  Container(
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
                  ),
              if (showBalancedOverlay)
                IgnorePointer(
                  child: _buildBalancedPresetOverlay(),
                ),
              if (showCinematicOverlay)
                IgnorePointer(
                  child: _buildCinematicPresetOverlay(),
                ),
              if (showVividOverlay)
                IgnorePointer(
                  child: _buildVividPresetOverlay(),
                ),
              if (showLowLightOverlay)
                IgnorePointer(
                  child: _buildLowLightPresetOverlay(),
                ),
              if (_showAfter && _selectedPresetIndex >= 0)
                IgnorePointer(
                  child: _buildSelectiveColorOverlay(),
                ),
              if (_showAfter && _selectedClip != null)
                IgnorePointer(
                  child: _buildSceneAwareOverlay(),
                ),
              if (hasVideo)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _showPreviewControls = !_showPreviewControls;
                      });
                    },
                  ),
                ),
              if (_isPreviewLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.32),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (hasSelectedClip)
                Positioned(
                  top: 18,
                  left: 18,
                  child: IgnorePointer(
                    ignoring: !showPlaybackControls,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: showPlaybackControls ? 1 : 0,
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
                          hasVideo
                              ? (_showAfter ? 'Imported Preview' : 'Original File')
                              : (_showAfter
                                  ? 'Enhanced Preview'
                                  : 'Original Preview'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasSelectedClip)
                Center(
                  child: IgnorePointer(
                    ignoring: !showPlaybackControls,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: showPlaybackControls ? 1 : 0,
                      child: GestureDetector(
                        onTap: hasVideo
                            ? () {
                                setState(() {
                                  if (controller.value.isPlaying) {
                                    controller.pause();
                                    _showPreviewControls = true;
                                  } else {
                                    controller.play();
                                    _showPreviewControls = false;
                                  }
                                });
                              }
                            : null,
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
                            hasVideo && controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasVideo)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: IgnorePointer(
                    ignoring: !showPlaybackControls,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: showPlaybackControls ? 1 : 0,
                      child: PlaybackTimelineOverlay(controller: controller),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClipShelf() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import Queue',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pick the video clip you want to shape.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            if (_clips.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF243651)),
                ),
                child: const Text(
                  'No imported videos yet. Tap Import Video above to add a clip.',
                  style: TextStyle(color: Colors.white70, height: 1.5),
                ),
              )
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: List.generate(_clips.length, (index) {
                  final clip = _clips[index];
                  final isSelected = index == _selectedClipIndex;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedClipIndex = index;
                        _sceneOverride = null;
                      });
                      _syncPreviewController();
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 250,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: isSelected
                            ? clip.accent.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: isSelected ? clip.accent : const Color(0xFF243651),
                          width: isSelected ? 1.4 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildClipThumbnail(clip),
                          const SizedBox(height: 14),
                          Text(
                            clip.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            clip.location,
                            style: const TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _tagChip(clip.tag),
                              const Spacer(),
                              Text(
                                clip.duration,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackTimeline(VideoPlayerController controller) {
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

  Widget _buildFilteredVideo(VideoPlayerController controller) {
    final video = VideoPlayer(controller);
    if (!_showAfter) {
      return video;
    }

    final gradedVideo = ColorFiltered(
      colorFilter: ColorFilter.matrix(_buildAdjustmentMatrix()),
      child: video,
    );

    return _buildSkinToneProtection(
      _buildTextureTreatment(gradedVideo),
    );
  }

  Widget _buildTextureTreatment(Widget gradedVideo) {
    final strength = _presetStrength;

    return switch (_selectedPresetIndex) {
      1 => Stack(
          fit: StackFit.expand,
          children: [
            gradedVideo,
            Opacity(
              opacity: 0.10 * strength,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 1.8 * strength,
                  sigmaY: 1.8 * strength,
                ),
                child: gradedVideo,
              ),
            ),
          ],
        ),
      2 => Stack(
          fit: StackFit.expand,
          children: [
            gradedVideo,
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.045 * strength),
                ),
              ),
            ),
          ],
        ),
      3 => Stack(
          fit: StackFit.expand,
          children: [
            gradedVideo,
            Opacity(
              opacity: 0.08 * strength,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 1.1 * strength,
                  sigmaY: 1.1 * strength,
                ),
                child: gradedVideo,
              ),
            ),
          ],
        ),
      _ => gradedVideo,
    };
  }

  Widget _buildSkinToneProtection(Widget processedVideo) {
    final strength = switch (_selectedPresetIndex) {
      1 => 0.10 * _presetStrength,
      2 => 0.08 * _presetStrength,
      3 => 0.09 * _presetStrength,
      _ => 0.04 * _presetStrength,
    };

    if (_selectedPresetIndex < 0 || strength <= 0) {
      return processedVideo;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        processedVideo,
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

  Widget _buildMiniPreviewOverlay() {
    final selectedClip = _selectedClip;
    final controller = _videoController;
    final hasVideo = controller != null && controller.value.isInitialized;
    const shellRadius = Radius.circular(22);

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.all(shellRadius),
      child: InkWell(
        onTap: _jumpToPreview,
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
                    child: hasVideo
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: controller.value.size.width,
                              height: controller.value.size.height,
                              child: _buildFilteredVideo(controller),
                            ),
                          )
                        : _buildMiniPreviewFallback(selectedClip),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  selectedClip?.title ?? 'Preview',
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

  Widget _buildMiniPreviewFallback(DemoClip? selectedClip) {
    if (selectedClip == null) {
      return Container(
        color: const Color(0xFF13213A),
      );
    }

    final filePath = selectedClip.filePath;
    final thumbnailBytes =
        filePath == null ? null : _clipThumbnails[filePath];

    if (thumbnailBytes != null) {
      return Image.memory(
        thumbnailBytes,
        fit: BoxFit.cover,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            selectedClip.accent.withValues(alpha: 0.55),
            const Color(0xFF101B2D),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.video_collection_rounded, size: 28),
      ),
    );
  }

  Widget _buildBalancedPresetOverlay() {
    final strength = _presetStrength;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.09 * strength),
                Colors.white.withValues(alpha: 0.02 * strength),
                const Color(0xFF09111F).withValues(alpha: 0.08 * strength),
              ],
              stops: const [0, 0.48, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.06,
              colors: [
                Colors.transparent,
                const Color(0xFF09111F).withValues(alpha: 0.05 * strength),
              ],
              stops: const [0.76, 1],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.82),
          child: Container(
            width: 220,
            height: 82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.10 * strength),
                  Colors.white.withValues(alpha: 0.03 * strength),
                  Colors.transparent,
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.54),
          child: Container(
            width: 260,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.06 * strength),
                  Colors.white.withValues(alpha: 0.015 * strength),
                  Colors.transparent,
                ],
                stops: const [0, 0.36, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCinematicPresetOverlay() {
    final strength = _presetStrength;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFB27A).withValues(alpha: 0.14 * strength),
                Colors.transparent,
                const Color(0xFF060A14).withValues(alpha: 0.34 * strength),
              ],
              stops: const [0, 0.36, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.02,
              colors: [
                Colors.transparent,
                const Color(0xFF060A14).withValues(alpha: 0.26 * strength),
              ],
              stops: const [0.54, 1],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.78),
          child: Container(
            width: 260,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFC38E).withValues(alpha: 0.14 * strength),
                  const Color(0xFFFFC38E).withValues(alpha: 0.05 * strength),
                  Colors.transparent,
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.18),
          child: Container(
            width: 300,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFD2A8).withValues(alpha: 0.08 * strength),
                  const Color(0xFFFFD2A8).withValues(alpha: 0.025 * strength),
                  Colors.transparent,
                ],
                stops: const [0, 0.34, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVividPresetOverlay() {
    final strength = _presetStrength;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF78D9FF).withValues(alpha: 0.13 * strength),
                Colors.transparent,
                const Color(0xFF6EFFC6).withValues(alpha: 0.12 * strength),
              ],
              stops: const [0, 0.50, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.12,
              colors: [
                Colors.white.withValues(alpha: 0.07 * strength),
                Colors.transparent,
                const Color(0xFF06101A).withValues(alpha: 0.10 * strength),
              ],
              stops: const [0, 0.42, 1],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.58, -0.36),
          child: Container(
            width: 180,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.08 * strength),
                  const Color(0xFF95F6FF).withValues(alpha: 0.03 * strength),
                  Colors.transparent,
                ],
                stops: const [0, 0.34, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLowLightPresetOverlay() {
    final strength = _presetStrength;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.05 * strength),
                const Color(0xFF8FC8FF).withValues(alpha: 0.08 * strength),
                Colors.transparent,
              ],
              stops: const [0, 0.30, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.14,
              colors: [
                Colors.white.withValues(alpha: 0.09 * strength),
                Colors.transparent,
                const Color(0xFF09111F).withValues(alpha: 0.08 * strength),
              ],
              stops: const [0, 0.48, 1],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.10),
          child: Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.08 * strength),
                  const Color(0xFFB6DCFF).withValues(alpha: 0.03 * strength),
                  Colors.transparent,
                ],
                stops: const [0, 0.34, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectiveColorOverlay() {
    final strength = _presetStrength;

    return switch (_selectedPresetIndex) {
      0 => Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: const Alignment(-0.72, -0.28),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7FD9FF).withValues(alpha: 0.030 * strength),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.66, 0.20),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF9AE7C1).withValues(alpha: 0.026 * strength),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      1 => Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: const Alignment(-0.62, 0.36),
              child: Container(
                width: 240,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF5EA1D6).withValues(alpha: 0.070 * strength),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.48, -0.54),
              child: Container(
                width: 220,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFA66E).withValues(alpha: 0.058 * strength),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      2 => Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: const Alignment(-0.58, -0.10),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6BCBFF).withValues(alpha: 0.090 * strength),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.62, 0.14),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF56F0B5).withValues(alpha: 0.082 * strength),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      _ => Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: const Alignment(-0.60, 0.28),
              child: Container(
                width: 260,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7AB7E9).withValues(alpha: 0.060 * strength),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.44, -0.42),
              child: Container(
                width: 170,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.030 * strength),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
    };
  }

  Widget _buildSceneAwareOverlay() {
    final strength = _presetStrength;

    return switch (_currentSceneFlavor) {
      SceneFlavor.portrait => Align(
          alignment: const Alignment(0, -0.12),
          child: Container(
            width: 240,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFC8A6).withValues(alpha: 0.045 * strength),
                  Colors.transparent,
                ],
                stops: const [0, 1],
              ),
            ),
          ),
        ),
      SceneFlavor.water => Align(
          alignment: const Alignment(-0.46, -0.16),
          child: Container(
            width: 280,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6ECEFF).withValues(alpha: 0.060 * strength),
                  Colors.transparent,
                ],
                stops: const [0, 1],
              ),
            ),
          ),
        ),
      SceneFlavor.nature => Align(
          alignment: const Alignment(0.34, 0.02),
          child: Container(
            width: 280,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF74E5A0).withValues(alpha: 0.050 * strength),
                  Colors.transparent,
                ],
                stops: const [0, 1],
              ),
            ),
          ),
        ),
      SceneFlavor.night => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A2D52).withValues(alpha: 0.045 * strength),
                Colors.transparent,
                const Color(0xFF060A14).withValues(alpha: 0.060 * strength),
              ],
              stops: const [0, 0.42, 1],
            ),
          ),
        ),
      SceneFlavor.urban => Align(
          alignment: const Alignment(-0.22, 0.10),
          child: Container(
            width: 320,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF6AA9FF).withValues(alpha: 0.028 * strength),
                  Colors.transparent,
                  const Color(0xFFFFB077).withValues(alpha: 0.028 * strength),
                ],
              ),
            ),
          ),
        ),
      SceneFlavor.animation => Align(
          alignment: const Alignment(0.12, -0.06),
          child: Container(
            width: 320,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8FE7FF).withValues(alpha: 0.070 * strength),
                  const Color(0xFF8C7CFF).withValues(alpha: 0.055 * strength),
                  Colors.transparent,
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
        ),
      SceneFlavor.socialEdit => Align(
          alignment: const Alignment(0.18, -0.02),
          child: Container(
            width: 340,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF67D8FF).withValues(alpha: 0.040 * strength),
                  Colors.transparent,
                  const Color(0xFFFF92C8).withValues(alpha: 0.040 * strength),
                ],
              ),
            ),
          ),
        ),
      SceneFlavor.neutral => const SizedBox.shrink(),
    };
  }

  // Builds the combined color matrix for the After view from manual controls and preset effects.
  List<double> _buildAdjustmentMatrix() {
    final brightnessOffset = (_brightness - 50) * 2.2;
    final contrastValue = 0.7 + (_contrast / 100) * 0.9;
    final saturationValue = 0.35 + (_saturation / 100) * 1.3;
    final warmthShift = (_warmth - 50) / 100 * 28;
    final tintShift = (_tint - 50) / 100 * 20;
    final highlightsOffset = (50 - _highlights) * 0.8;
    final shadowsOffset = (_shadows - 50) * 0.7;
    final presetStrength = _showAfter ? _presetStrength : 0.0;
    final curve = _presetToneCurve(presetStrength);
    final clarityBoost = switch (_selectedPresetIndex) {
      0 when _showAfter => 1.0 + (0.05 * presetStrength),
      2 when _showAfter => 1.0 + (0.08 * presetStrength),
      _ => 1.0,
    };
    final cinematicFade =
        _showAfter && _selectedPresetIndex == 1 ? 10.0 * presetStrength : 0.0;
    final lowLightLift =
        _showAfter && _selectedPresetIndex == 3 ? 8.0 * presetStrength : 0.0;

    final contrastMatrix = _contrastMatrix(
      contrastValue,
      translate: 128 * (1 - contrastValue),
    );
    final saturationMatrix = _saturationMatrix(saturationValue);
    final warmthMatrix = _warmthMatrix(warmthShift);
    final tintMatrix = _tintMatrix(tintShift);
    final brightnessMatrix = _brightnessMatrix(brightnessOffset);
    final clarityMatrix = _contrastMatrix(
      clarityBoost,
      translate: 128 * (1 - clarityBoost),
    );
    final fadeMatrix = _brightnessMatrix(cinematicFade);
    final lowLightLiftMatrix = _brightnessMatrix(lowLightLift);
    final highlightsMatrix = _brightnessMatrix(highlightsOffset);
    final shadowsMatrix = _brightnessMatrix(shadowsOffset);
    final sceneTintMatrix = _tintMatrix(_sceneToneAdjustment().tintShift);
    final sceneBrightnessMatrix = _brightnessMatrix(
      _sceneToneAdjustment().brightnessLift,
    );
    final curveShadowLiftMatrix = _brightnessMatrix(curve.shadowLift);
    final curveMidtoneMatrix = _brightnessMatrix(curve.midtoneLift);
    final curveContrastMatrix = _contrastMatrix(
      curve.contrast,
      translate: 128 * (1 - curve.contrast) + curve.blackLift,
    );

    return _multiplyColorMatrices(
      sceneBrightnessMatrix,
      _multiplyColorMatrices(
        sceneTintMatrix,
        _multiplyColorMatrices(
          curveShadowLiftMatrix,
          _multiplyColorMatrices(
            curveMidtoneMatrix,
            _multiplyColorMatrices(
              curveContrastMatrix,
              _multiplyColorMatrices(
                highlightsMatrix,
                _multiplyColorMatrices(
                  shadowsMatrix,
                  _multiplyColorMatrices(
                    lowLightLiftMatrix,
                    _multiplyColorMatrices(
                      fadeMatrix,
                      _multiplyColorMatrices(
                        clarityMatrix,
                        _multiplyColorMatrices(
                          brightnessMatrix,
                          _multiplyColorMatrices(
                            tintMatrix,
                            _multiplyColorMatrices(
                              warmthMatrix,
                              _multiplyColorMatrices(
                                saturationMatrix,
                                contrastMatrix,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Defines per-preset tonal shaping so each preset has a different contrast/black response.
  ({
    double contrast,
    double blackLift,
    double shadowLift,
    double midtoneLift,
  }) _presetToneCurve(double strength) {
    return switch (_selectedPresetIndex) {
      0 when _showAfter => (
          contrast: 1.0 + (0.04 * strength),
          blackLift: 2.0 * strength,
          shadowLift: 1.6 * strength,
          midtoneLift: 0.8 * strength,
        ),
      1 when _showAfter => (
          contrast: 1.0 + (0.08 * strength),
          blackLift: 7.5 * strength,
          shadowLift: 0.8 * strength,
          midtoneLift: -1.2 * strength,
        ),
      2 when _showAfter => (
          contrast: 1.0 + (0.09 * strength),
          blackLift: 0.5 * strength,
          shadowLift: -0.6 * strength,
          midtoneLift: 2.6 * strength,
        ),
      3 when _showAfter => (
          contrast: 1.0 + (0.02 * strength),
          blackLift: 5.0 * strength,
          shadowLift: 4.6 * strength,
          midtoneLift: 1.4 * strength,
        ),
      _ => (
          contrast: 1.0,
          blackLift: 0.0,
          shadowLift: 0.0,
          midtoneLift: 0.0,
        ),
    };
  }

  // Adds small scene-specific nudges so auto/manual scene selection influences the final grade.
  ({double tintShift, double brightnessLift}) _sceneToneAdjustment() {
    if (!_showAfter) {
      return (tintShift: 0.0, brightnessLift: 0.0);
    }

    return switch (_currentSceneFlavor) {
      SceneFlavor.portrait => (tintShift: 1.2, brightnessLift: 1.2),
      SceneFlavor.water => (tintShift: -1.6, brightnessLift: 1.4),
      SceneFlavor.nature => (tintShift: -0.8, brightnessLift: 0.8),
      SceneFlavor.night => (tintShift: -1.4, brightnessLift: 1.6),
      SceneFlavor.urban => (tintShift: 0.4, brightnessLift: 0.6),
      SceneFlavor.animation => (tintShift: -0.6, brightnessLift: 2.0),
      SceneFlavor.socialEdit => (tintShift: 0.8, brightnessLift: 2.2),
      SceneFlavor.neutral => (tintShift: 0.0, brightnessLift: 0.0),
    };
  }

  // Returns a simple brightness offset matrix.
  List<double> _brightnessMatrix(double offset) {
    return [
      1, 0, 0, 0, offset,
      0, 1, 0, 0, offset,
      0, 0, 1, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  // Returns a contrast matrix with optional translation to preserve midtone positioning.
  List<double> _contrastMatrix(double value, {double translate = 0}) {
    return [
      value, 0, 0, 0, translate,
      0, value, 0, 0, translate,
      0, 0, value, 0, translate,
      0, 0, 0, 1, 0,
    ];
  }

  // Returns a saturation matrix based on luminance-preserving channel weights.
  List<double> _saturationMatrix(double value) {
    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;
    final inv = 1 - value;

    return [
      lumR * inv + value, lumG * inv, lumB * inv, 0, 0,
      lumR * inv, lumG * inv + value, lumB * inv, 0, 0,
      lumR * inv, lumG * inv, lumB * inv + value, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  // Pushes the image warmer or cooler by balancing red against blue.
  List<double> _warmthMatrix(double shift) {
    return [
      1.0, 0, 0, 0, shift,
      0, 1.0, 0, 0, 0,
      0, 0, 1.0, 0, -shift,
      0, 0, 0, 1, 0,
    ];
  }

  // Shifts the image along the green-magenta axis to complement warmth.
  List<double> _tintMatrix(double shift) {
    return [
      1.0, 0, 0, 0, shift * 0.45,
      0, 1.0, 0, 0, -shift,
      0, 0, 1.0, 0, shift * 0.45,
      0, 0, 0, 1, 0,
    ];
  }

  // Multiplies two 4x5 color matrices so multiple looks can be applied as one filter.
  List<double> _multiplyColorMatrices(List<double> a, List<double> b) {
    final result = List<double>.filled(20, 0);

    for (var row = 0; row < 4; row++) {
      final rowOffset = row * 5;
      for (var col = 0; col < 5; col++) {
        result[rowOffset + col] =
            a[rowOffset] * b[col] +
            a[rowOffset + 1] * b[col + 5] +
            a[rowOffset + 2] * b[col + 10] +
            a[rowOffset + 3] * b[col + 15] +
            (col == 4 ? a[rowOffset + 4] : 0);
      }
    }

    return result;
  }

  Widget _buildClipThumbnail(DemoClip clip) {
    final filePath = clip.filePath;
    final thumbnailBytes =
        filePath == null ? null : _clipThumbnails[filePath];

    return Container(
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            clip.accent.withValues(alpha: 0.55),
            const Color(0xFF101B2D),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: thumbnailBytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    thumbnailBytes,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : const Center(
                child: Icon(Icons.video_collection_rounded, size: 36),
              ),
      ),
    );
  }

  Widget _tagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  // Converts a picked file into the app's clip model with placeholder metadata.
  DemoClip _buildImportedClip(PlatformFile file) {
    const accents = [
      Color(0xFF77B6FF),
      Color(0xFF68E0C1),
      Color(0xFFFFA66B),
      Color(0xFFD7A5FF),
    ];

    final accent = accents[_clips.length % accents.length];
    final normalizedName = file.name.trim().isEmpty ? 'Imported Video' : file.name;

    return DemoClip(
      title: normalizedName,
      location: _formatImportSource(file),
      duration: '--:--',
      accent: accent,
      tag: 'Imported',
      filePath: file.path,
    );
  }

  // Generates queue thumbnails lazily so imported clips can show real frame previews.
  Future<void> _generateThumbnails(List<DemoClip> clips) async {
    for (final clip in clips) {
      final filePath = clip.filePath;
      if (filePath == null || filePath.isEmpty || _clipThumbnails.containsKey(filePath)) {
        continue;
      }

      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: filePath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 360,
          quality: 70,
          timeMs: 500,
        );

        if (!mounted || bytes == null) {
          continue;
        }

        setState(() {
          _clipThumbnails[filePath] = bytes;
        });
      } catch (_) {
        continue;
      }
    }
  }

  // Formats lightweight file metadata for the import queue subtitle.
  String _formatImportSource(PlatformFile file) {
    final extension = file.extension;
    final sizeInMb = file.size / (1024 * 1024);
    final sizeLabel = sizeInMb >= 1
        ? '${sizeInMb.toStringAsFixed(1)} MB'
        : '${(file.size / 1024).toStringAsFixed(0)} KB';

    if (extension == null || extension.isEmpty) {
      return 'From device • $sizeLabel';
    }

    return '${extension.toUpperCase()} • $sizeLabel';
  }

  // Formats a video duration into mm:ss for queue and preview labels.
  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Writes a resolved runtime duration back onto the matching imported clip.
  void _updateClipDuration(String filePath, String durationLabel) {
    final clipIndex = _clips.indexWhere((clip) => clip.filePath == filePath);
    if (clipIndex == -1 || _clips[clipIndex].duration == durationLabel) {
      return;
    }

    _clips[clipIndex] = _clips[clipIndex].copyWith(duration: durationLabel);
  }

  // Rebuilds the preview player whenever the selected imported clip changes.
  Future<void> _syncPreviewController() async {
    final previousController = _videoController;
    _videoController = null;

    final filePath = _selectedClip?.filePath;
    if (filePath == null || filePath.isEmpty) {
      await previousController?.dispose();
      if (mounted) {
        setState(() {
          _isPreviewLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isPreviewLoading = true;
      });
    }

    final controller = VideoPlayerController.file(File(filePath));
    await previousController?.dispose();

    try {
      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted || _selectedClip?.filePath != filePath) {
        await controller.dispose();
        return;
      }

      _updateClipDuration(
        filePath,
        _formatDuration(controller.value.duration),
      );

      setState(() {
        _videoController = controller;
        _isPreviewLoading = false;
        _showPreviewControls = true;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _isPreviewLoading = false;
        });
      }
    }
  }

  Widget _buildAnalysisCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Scene Analysis',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _analysisSummary,
              style: const TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 18),
            const Text(
              'Scene Type',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Leave this on Auto or guide the analyzer with the kind of footage you imported.',
              style: TextStyle(color: Colors.white60, height: 1.45),
            ),
            const SizedBox(height: 12),
            _buildSceneTypeScroller(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _isAnalyzing ? null : _analysisConfidence / 100,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  _isAnalyzing ? 'Analyzing...' : '$_analysisConfidence%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _analysisSignals
                  .map(
                    (signal) => _InsightPill(
                      label: signal.split(':').first,
                      value: signal.contains(':')
                          ? signal.split(':').skip(1).join(':').trim()
                          : signal,
                    ),
                  )
                  .toList(),
            ),
            if (_analysisRecommendedPresetIndex != null) ...[
              const SizedBox(height: 18),
              Text(
                'Suggested preset: ${_presets[_analysisRecommendedPresetIndex!].title}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _runAiAnalysis,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high_rounded),
              label: Text(_isAnalyzing ? 'Analyzing Clip' : 'Run AI Pass'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enhancement Presets',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            _buildNoPresetOption(),
            const SizedBox(height: 12),
            ...List.generate(_presets.length, (index) {
              final preset = _presets[index];
              final isSelected = index == _selectedPresetIndex;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == _presets.length - 1 ? 0 : 12,
                ),
                child: InkWell(
                  onTap: () {
                    _applyPreset(index);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isSelected
                          ? preset.accent.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: isSelected ? preset.accent : const Color(0xFF22324D),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: preset.accent.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(preset.icon, color: preset.accent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preset.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                preset.subtitle,
                                style: const TextStyle(color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (_selectedPresetIndex >= 0) ...[
              const SizedBox(height: 18),
              _buildSlider(
                label: 'Preset Strength',
                value: _presetStrength * 100,
                onChanged: (value) {
                  setState(() {
                    _presetStrength = value / 100;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoPresetOption() {
    final isSelected = _selectedPresetIndex == -1;
    return InkWell(
      onTap: _clearPreset,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isSelected ? Colors.white70 : const Color(0xFF22324D),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block_rounded, size: 18, color: Colors.white70),
            const SizedBox(width: 10),
            const Text(
              'No Preset',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 10),
              const Icon(Icons.check_circle_rounded, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustmentsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manual Adjustments',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adjust the video accordingly to how you prefer. Use the sliders the below to get a specific value.',
              style: TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 18),
            _buildSlider(
              label: 'Brightness',
              value: _brightness,
              onChanged: (value) => setState(() => _brightness = value),
            ),
            _buildSlider(
              label: 'Contrast',
              value: _contrast,
              onChanged: (value) => setState(() => _contrast = value),
            ),
            _buildSlider(
              label: 'Saturation',
              value: _saturation,
              onChanged: (value) => setState(() => _saturation = value),
            ),
            _buildSlider(
              label: 'Warmth',
              value: _warmth,
              onChanged: (value) => setState(() => _warmth = value),
            ),
            _buildSlider(
              label: 'Tint',
              value: _tint,
              onChanged: (value) => setState(() => _tint = value),
            ),
            _buildSlider(
              label: 'Highlights',
              value: _highlights,
              onChanged: (value) => setState(() => _highlights = value),
            ),
            _buildSlider(
              label: 'Shadows',
              value: _shadows,
              onChanged: (value) => setState(() => _shadows = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneTypeScroller() {
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildSceneChip(
                label: 'Auto',
                selected: _sceneOverride == null,
                onTap: () => _setSceneOverride(null),
              ),
              const SizedBox(width: 10),
              ...SceneFlavor.values.expand((flavor) {
                return [
                  _buildSceneChip(
                    label: _sceneFlavorLabel(flavor),
                    selected: _sceneOverride == flavor,
                    onTap: () => _setSceneOverride(flavor),
                  ),
                  const SizedBox(width: 10),
                ];
              }),
            ],
          ),
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _ScrollerFade(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _ScrollerFade(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white70 : const Color(0xFF22324D),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                value.round().toString(),
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 100,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export Enhanced Video',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Placeholder settings for codec, resolution, and delivery output.',
                    style: TextStyle(color: Colors.white60, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _exportInfo('Resolution', '4K UHD')),
                const SizedBox(width: 12),
                Expanded(child: _exportInfo('Format', 'H.264 MP4')),
                const SizedBox(width: 12),
                Expanded(child: _exportInfo('Bitrate', '24 Mbps')),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _showExportMessage,
              icon: const Icon(Icons.file_download_done_rounded),
              label: const Text('Start Placeholder Export'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF20304A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InsightPill extends StatelessWidget {
  const _InsightPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white60),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameAnalysisStats {
  const _FrameAnalysisStats({
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

class _ScrollerFade extends StatelessWidget {
  const _ScrollerFade({
    required this.begin,
    required this.end,
  });

  final Alignment begin;
  final Alignment end;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: const [
            Color(0xFF121D31),
            Color(0x00121D31),
          ],
        ),
      ),
    );
  }
}

class FramePainter extends CustomPainter {
  FramePainter({
    required this.accent,
    required this.emphasizeEnhancement,
  });

  final Color accent;
  final bool emphasizeEnhancement;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: emphasizeEnhancement ? 0.28 : 0.12),
          Colors.transparent,
          Colors.white.withValues(alpha: emphasizeEnhancement ? 0.08 : 0.03),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(28),
      ),
      fill,
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = emphasizeEnhancement ? 2.3 : 1.4
      ..color = accent.withValues(alpha: emphasizeEnhancement ? 0.55 : 0.22);

    final wave = Path()..moveTo(0, size.height * 0.76);
    for (double x = 0; x <= size.width; x += 12) {
      final progress = x / size.width;
      final amplitude = emphasizeEnhancement ? 22.0 : 14.0;
      final y =
          size.height * 0.68 +
          math.sin(progress * math.pi * 2.8) * amplitude +
          math.cos(progress * math.pi * 5.6) * 7;
      wave.lineTo(x, y);
    }

    canvas.drawPath(wave, stroke);

    final glow = Paint()
      ..color = Colors.white.withValues(
        alpha: emphasizeEnhancement ? 0.10 : 0.05,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.30),
      emphasizeEnhancement ? 78 : 52,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant FramePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.emphasizeEnhancement != emphasizeEnhancement;
  }
}
