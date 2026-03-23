import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'helpers/analyzer_helper.dart';
import 'helpers/color_grading.dart';
import 'models/demo_clip.dart';
import 'models/enhancement_preset.dart';
import 'widgets/adjustments_card.dart';
import 'widgets/analysis_card.dart';
import 'widgets/preview_media.dart';
import 'widgets/presets_card.dart';
import 'widgets/video_effect_overlays.dart';
import 'widgets/frame_painter.dart';
import 'widgets/video_preview_card.dart';

// TODO: Refactor main.dart and split models/UI sections into different files to maintain readability
void main() {
  runApp(const VideoEnhancerApp());
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
    return AnalyzerHelper.sceneFlavorForClip(clip);
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

  String _sceneFlavorLabel(SceneFlavor flavor) {
    return AnalyzerHelper.sceneFlavorLabel(flavor);
  }

  // Stores the user's explicit scene override choice, or returns to auto mode with null.
  void _setSceneOverride(SceneFlavor? flavor) {
    setState(() {
      _sceneOverride = flavor;
    });
  }
  
  Future<({
    int presetIndex,
    int confidence,
    String summary,
    List<String> signals,
  })> _analyzeClipRecommendation(DemoClip clip) async {
    final recommendation = AnalyzerHelper.analyzeRecommendation(
      clip: clip,
      scene: _currentSceneFlavor,
      frameStats: await _analyzeVideoFrames(clip),
      presetTitles: _presets.map((preset) => preset.title).toList(),
    );

    return (
      presetIndex: recommendation.presetIndex,
      confidence: recommendation.confidence,
      summary: recommendation.summary,
      signals: recommendation.signals,
    );
  }

  // Samples multiple points in the video and averages their image statistics into one profile.
  Future<FrameAnalysisStats?> _analyzeVideoFrames(DemoClip clip) async {
    final filePath = clip.filePath;
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    final durationMs = _selectedClip?.filePath == filePath &&
            _videoController?.value.isInitialized == true
        ? _videoController!.value.duration.inMilliseconds
        : 0;
    return AnalyzerHelper.analyzeVideoFrames(
      filePath: filePath,
      durationMs: durationMs > 0 ? durationMs : 6000,
      seed: filePath.hashCode ^ clip.title.hashCode,
    );
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
                        ? 'Auto - ${_sceneFlavorLabel(_currentSceneFlavor)}'
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

    return VideoPreviewViewport(
      aspectRatio: hasVideo ? controller.value.aspectRatio : 16 / 9,
      backgroundColors: _showAfter
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
      media: hasVideo
          ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: FilteredPreviewMedia(
                  controller: controller,
                  showAfter: _showAfter,
                  adjustmentMatrix: _buildAdjustmentMatrix(),
                  selectedPresetIndex: _selectedPresetIndex,
                  presetStrength: _presetStrength,
                ),
              ),
            )
          : selectedClip != null
          ? CustomPaint(
              painter: FramePainter(
                accent: selectedClip.accent,
                emphasizeEnhancement: _showAfter,
              ),
            )
          : const EmptyPreviewMessage(),
      effectOverlays: [
        if (showBalancedOverlay)
          IgnorePointer(child: BalancedPresetOverlay(strength: _presetStrength)),
        if (showCinematicOverlay)
          IgnorePointer(child: CinematicPresetOverlay(strength: _presetStrength)),
        if (showVividOverlay)
          IgnorePointer(child: VividPresetOverlay(strength: _presetStrength)),
        if (showLowLightOverlay)
          IgnorePointer(child: LowLightPresetOverlay(strength: _presetStrength)),
        if (_showAfter && _selectedPresetIndex >= 0)
          IgnorePointer(
            child: SelectiveColorOverlay(
              presetIndex: _selectedPresetIndex,
              strength: _presetStrength,
            ),
          ),
        if (_showAfter && selectedClip != null)
          IgnorePointer(
            child: SceneAwareOverlay(
              sceneFlavor: _currentSceneFlavor,
              strength: _presetStrength,
            ),
          ),
      ],
      isPreviewLoading: _isPreviewLoading,
      onBackgroundTap: hasVideo
          ? () {
              setState(() {
                _showPreviewControls = !_showPreviewControls;
              });
            }
          : null,
      topLeftBadge: hasSelectedClip
          ? PreviewStatusBadge(
              label: hasVideo
                  ? (_showAfter ? 'Imported Preview' : 'Original File')
                  : (_showAfter ? 'Enhanced Preview' : 'Original Preview'),
              visible: showPlaybackControls,
            )
          : null,
      centerControl: hasSelectedClip
          ? PreviewPlaybackButton(
              visible: showPlaybackControls,
              isPlaying: hasVideo && controller.value.isPlaying,
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
            )
          : null,
      bottomOverlay: hasVideo
          ? IgnorePointer(
              ignoring: !showPlaybackControls,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: showPlaybackControls ? 1 : 0,
                child: PlaybackTimelineOverlay(controller: controller),
              ),
            )
          : null,
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

  Widget _buildMiniPreviewOverlay() {
    final selectedClip = _selectedClip;
    final controller = _videoController;
    final hasVideo = controller != null && controller.value.isInitialized;
    final thumbnailBytes = selectedClip?.filePath == null
        ? null
        : _clipThumbnails[selectedClip!.filePath!];

    return MiniPreviewCard(
      title: selectedClip?.title ?? 'Preview',
      onTap: _jumpToPreview,
      media: hasVideo
          ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: FilteredPreviewMedia(
                  controller: controller,
                  showAfter: _showAfter,
                  adjustmentMatrix: _buildAdjustmentMatrix(),
                  selectedPresetIndex: _selectedPresetIndex,
                  presetStrength: _presetStrength,
                ),
              ),
            )
          : MiniPreviewFallback(
              thumbnailBytes: thumbnailBytes,
              accentColor: selectedClip?.accent,
            ),
    );
  }

  // Builds the combined color matrix for the After view from manual controls and preset effects.
  List<double> _buildAdjustmentMatrix() {
    final sceneTone = _sceneToneAdjustment();
    return ColorGrading.buildAdjustmentMatrix(
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      warmth: _warmth,
      tint: _tint,
      highlights: _highlights,
      shadows: _shadows,
      showAfter: _showAfter,
      presetStrength: _presetStrength,
      selectedPresetIndex: _selectedPresetIndex,
      sceneTintShift: sceneTone.tintShift,
      sceneBrightnessLift: sceneTone.brightnessLift,
    );
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
      return 'From device - $sizeLabel';
    }

    return '${extension.toUpperCase()} - $sizeLabel';
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
    return AnalysisCard(
      summary: _analysisSummary,
      sceneOptions: [
        SceneTypeOption(
          label: 'Auto',
          selected: _sceneOverride == null,
          onTap: () => _setSceneOverride(null),
        ),
        ...SceneFlavor.values.map(
          (flavor) => SceneTypeOption(
            label: _sceneFlavorLabel(flavor),
            selected: _sceneOverride == flavor,
            onTap: () => _setSceneOverride(flavor),
          ),
        ),
      ],
      isAnalyzing: _isAnalyzing,
      confidence: _analysisConfidence,
      signals: _analysisSignals,
      suggestedPresetTitle: _analysisRecommendedPresetIndex == null
          ? null
          : _presets[_analysisRecommendedPresetIndex!].title,
      onRunAnalysis: _runAiAnalysis,
    );
  }

  Widget _buildPresetCard() {
    return PresetsCard(
      presets: _presets,
      selectedPresetIndex: _selectedPresetIndex,
      onSelectPreset: _applyPreset,
      onClearPreset: _clearPreset,
      presetStrength: _presetStrength,
      onPresetStrengthChanged: (value) {
        setState(() {
          _presetStrength = value / 100;
        });
      },
    );
  }

  Widget _buildAdjustmentsCard() {
    return AdjustmentsCard(
      controls: [
        AdjustmentControl(
          label: 'Brightness',
          value: _brightness,
          onChanged: (value) => setState(() => _brightness = value),
        ),
        AdjustmentControl(
          label: 'Contrast',
          value: _contrast,
          onChanged: (value) => setState(() => _contrast = value),
        ),
        AdjustmentControl(
          label: 'Saturation',
          value: _saturation,
          onChanged: (value) => setState(() => _saturation = value),
        ),
        AdjustmentControl(
          label: 'Warmth',
          value: _warmth,
          onChanged: (value) => setState(() => _warmth = value),
        ),
        AdjustmentControl(
          label: 'Tint',
          value: _tint,
          onChanged: (value) => setState(() => _tint = value),
        ),
        AdjustmentControl(
          label: 'Highlights',
          value: _highlights,
          onChanged: (value) => setState(() => _highlights = value),
        ),
        AdjustmentControl(
          label: 'Shadows',
          value: _shadows,
          onChanged: (value) => setState(() => _shadows = value),
        ),
      ],
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


