import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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
  double _presetStrength = 0.85;
  VideoPlayerController? _videoController;
  bool _isPreviewLoading = false;
  final Map<String, Uint8List> _clipThumbnails = {};
  bool _showPreviewJumpButton = false;

  DemoClip? get _selectedClip =>
      _clips.isEmpty ? null : _clips[_selectedClipIndex];
  EnhancementPreset? get _selectedPreset =>
      _selectedPresetIndex >= 0 ? _presets[_selectedPresetIndex] : null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
    _syncPreviewController();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

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

  void _clearPreset() {
    setState(() {
      _selectedPresetIndex = -1;
    });
  }

  void _applyPreset(int presetIndex) {
    final settings = switch (presetIndex) {
      0 => (brightness: 51.0, contrast: 61.0, saturation: 52.0, warmth: 50.0),
      1 => (brightness: 44.0, contrast: 78.0, saturation: 58.0, warmth: 61.0),
      2 => (brightness: 58.0, contrast: 72.0, saturation: 84.0, warmth: 48.0),
      _ => (brightness: 70.0, contrast: 48.0, saturation: 44.0, warmth: 57.0),
    };

    setState(() {
      _selectedPresetIndex = presetIndex;
      _brightness = settings.brightness;
      _contrast = settings.contrast;
      _saturation = settings.saturation;
      _warmth = settings.warmth;
      _presetStrength = 0.85;
    });
  }

  Future<void> _runAiAnalysis() async {
    final selectedClip = _selectedClip;
    if (_isAnalyzing || selectedClip == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    final title = selectedClip.title.toLowerCase();
    final presetIndex = switch (title) {
      String value when value.contains('street') => 0,
      String value when value.contains('ocean') => 2,
      _ => 3,
    };

    setState(() {
      _isAnalyzing = false;
    });
    _applyPreset(presetIndex);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'AI Scene Analysis recommended "${_presets[presetIndex].title}" for ${selectedClip.title}.',
        ),
      ),
    );
  }

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

  void _showExportMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Export Enhanced Video is a placeholder for the rendering pipeline.',
        ),
      ),
    );
  }

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
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: IgnorePointer(
                  ignoring: !_showPreviewJumpButton,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _showPreviewJumpButton ? 1 : 0,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: _jumpToPreview,
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('Back To Preview'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
                          : (_showAfter ? 'Enhanced Preview' : 'Original Preview'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (hasSelectedClip)
                Center(
                  child: GestureDetector(
                    onTap: hasVideo
                        ? () {
                            setState(() {
                              if (controller.value.isPlaying) {
                                controller.pause();
                              } else {
                                controller.play();
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
              if (hasSelectedClip)
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasVideo ? 'Imported file' : 'Preview gain',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasVideo
                              ? (selectedClip.duration == '--:--'
                                  ? 'Ready'
                                  : selectedClip.duration)
                              : '+${(_qualityScore / 5).round()}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
              'Pick the placeholder clip you want to shape.',
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

  Widget _buildFilteredVideo(VideoPlayerController controller) {
    final video = VideoPlayer(controller);
    if (!_showAfter) {
      return video;
    }

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_buildAdjustmentMatrix()),
      child: video,
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

  List<double> _buildAdjustmentMatrix() {
    final brightnessOffset = (_brightness - 50) * 2.2;
    final contrastValue = 0.7 + (_contrast / 100) * 0.9;
    final saturationValue = 0.35 + (_saturation / 100) * 1.3;
    final warmthShift = (_warmth - 50) / 100 * 28;
    final presetStrength = _showAfter ? _presetStrength : 0.0;
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
    final brightnessMatrix = _brightnessMatrix(brightnessOffset);
    final clarityMatrix = _contrastMatrix(
      clarityBoost,
      translate: 128 * (1 - clarityBoost),
    );
    final fadeMatrix = _brightnessMatrix(cinematicFade);
    final lowLightLiftMatrix = _brightnessMatrix(lowLightLift);

    return _multiplyColorMatrices(
      lowLightLiftMatrix,
      _multiplyColorMatrices(
        fadeMatrix,
        _multiplyColorMatrices(
          clarityMatrix,
          _multiplyColorMatrices(
            brightnessMatrix,
            _multiplyColorMatrices(
              warmthMatrix,
              _multiplyColorMatrices(saturationMatrix, contrastMatrix),
            ),
          ),
        ),
      ),
    );
  }

  List<double> _brightnessMatrix(double offset) {
    return [
      1, 0, 0, 0, offset,
      0, 1, 0, 0, offset,
      0, 0, 1, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _contrastMatrix(double value, {double translate = 0}) {
    return [
      value, 0, 0, 0, translate,
      0, value, 0, 0, translate,
      0, 0, value, 0, translate,
      0, 0, 0, 1, 0,
    ];
  }

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

  List<double> _warmthMatrix(double shift) {
    return [
      1.0, 0, 0, 0, shift,
      0, 1.0, 0, 0, 0,
      0, 0, 1.0, 0, -shift,
      0, 0, 0, 1, 0,
    ];
  }

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

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _updateClipDuration(String filePath, String durationLabel) {
    final clipIndex = _clips.indexWhere((clip) => clip.filePath == filePath);
    if (clipIndex == -1 || _clips[clipIndex].duration == durationLabel) {
      return;
    }

    _clips[clipIndex] = _clips[clipIndex].copyWith(duration: durationLabel);
  }

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
            const Text(
              'Placeholder intelligence that recommends a look based on the selected scene.',
              style: TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _isAnalyzing ? null : _qualityScore / 100,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  _isAnalyzing ? 'Analyzing...' : '$_qualityScore%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _InsightPill(label: 'Noise reduction', value: 'Medium'),
                _InsightPill(label: 'Motion stability', value: 'High'),
                _InsightPill(label: 'Face recovery', value: 'Active'),
              ],
            ),
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
          ],
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
