import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'helpers/analyzer_helper.dart';
import 'helpers/color_grading.dart';
import 'models/demo_clip.dart';
import 'models/enhancement_preset.dart';
import 'widgets/adjustments_card.dart';
import 'widgets/analysis_card.dart';
import 'widgets/preview_media.dart';
import 'widgets/presets_card.dart';
import 'widgets/frame_painter.dart';
import 'widgets/video_preview_card.dart';

void main() {
  runApp(const VideoEnhancerApp());
}

enum ExportDestination {
  originalFolder,
  customFolder,
}

enum ExportFormat {
  mp4,
  mov,
}

enum ExportResolution {
  source,
  p1080,
  p720,
}

enum ExportBitrate {
  low,
  medium,
  high,
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
  static const MethodChannel _mediaScannerChannel = MethodChannel(
    'videoenhancerapp/media_scanner',
  );

  final List<DemoClip> _clips = [];
  final GlobalKey _previewSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _exportFileNameController =
      TextEditingController();

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
      subtitle: 'Brightens dim footage with cleaner tone',
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
  double _presetStrength = 0.85;
  bool _showPresetOverlay = true;
  SceneFlavor? _sceneOverride;
  VideoPlayerController? _videoController;
  bool _isPreviewLoading = false;
  String? _previewErrorMessage;
  final Map<String, Uint8List> _clipThumbnails = {};
  bool _showPreviewJumpButton = false;
  bool _showPreviewControls = true;
  bool _isExporting = false;
  ExportDestination _exportDestination = ExportDestination.originalFolder;
  ExportFormat _exportFormat = ExportFormat.mp4;
  ExportResolution _exportResolution = ExportResolution.source;
  ExportBitrate _exportBitrate = ExportBitrate.medium;
  String? _customExportDirectory;
  String _exportStatusMessage = 'Ready to export the selected clip.';
  String? _lastExportPath;
  bool _lastExportSucceeded = false;
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
    _syncExportFileName();
    _syncPreviewController();
  }

  @override
  // Cleans up controllers created for scrolling and video playback.
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _exportFileNameController.dispose();
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

    setState(() {
      _selectedPresetIndex = presetIndex;
      _brightness = settings.brightness;
      _contrast = settings.contrast;
      _saturation = settings.saturation;
      _warmth = settings.warmth;
      _tint = colorBalance;
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
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (!mounted) {
        return;
      }

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No video was selected.'),
          ),
        );
        return;
      }

      final importableFiles = result.files.where((file) {
        final path = file.path;
        return path != null && path.isNotEmpty;
      }).toList();

      if (importableFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This device did not provide a usable file path for the selected video.',
            ),
          ),
        );
        return;
      }

      final importedClips = importableFiles.map(_buildImportedClip).toList();

      setState(() {
        _clips.addAll(importedClips);
        _selectedClipIndex = _clips.length - importedClips.length;
        _sceneOverride = null;
        _previewErrorMessage = null;
        _syncExportFileName();
      });

      _generateThumbnails(importedClips);
      await _syncPreviewController();

      if (!mounted) {
        return;
      }

      final clipLabel = importedClips.length == 1 ? 'video' : 'videos';
      final skippedCount = result.files.length - importableFiles.length;
      final message = skippedCount > 0
          ? 'Imported ${importedClips.length} $clipLabel. Skipped $skippedCount file${skippedCount == 1 ? '' : 's'} without a usable path.'
          : 'Imported ${importedClips.length} $clipLabel into the queue.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Video import failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video import failed: $error'),
        ),
      );
    }
  }

  String _buildExportOutputPath(String inputPath) {
    final inputFile = File(inputPath);
    final parentPath = switch (_exportDestination) {
      ExportDestination.originalFolder => inputFile.parent.path,
      ExportDestination.customFolder when _customExportDirectory != null =>
        _customExportDirectory!,
      _ => inputFile.parent.path,
    };
    final originalName = inputFile.path.split(RegExp(r'[\\/]')).last;
    final dotIndex = originalName.lastIndexOf('.');
    final hasExtension = dotIndex > 0;
    final originalBaseName = hasExtension
        ? originalName.substring(0, dotIndex)
        : originalName;
    final customBaseName = _sanitizeExportFileName(
      _exportFileNameController.text,
    );
    final baseName = customBaseName.isEmpty ? originalBaseName : customBaseName;
    final extension = switch (_exportFormat) {
      ExportFormat.mp4 => '.mp4',
      ExportFormat.mov => '.mov',
    };
    return '$parentPath${Platform.pathSeparator}$baseName$extension';
  }

  void _syncExportFileName() {
    final clip = _selectedClip;
    if (clip == null) {
      _exportFileNameController.text = '';
      return;
    }

    final originalName = clip.title;
    final dotIndex = originalName.lastIndexOf('.');
    final defaultBaseName = dotIndex > 0
        ? originalName.substring(0, dotIndex)
        : originalName;
    _exportFileNameController.text = defaultBaseName;
  }

  String _sanitizeExportFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _pickExportDirectory() async {
    try {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select export folder',
        lockParentWindow: true,
      );

      if (!mounted) {
        return;
      }

      if (directoryPath == null || directoryPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No export folder was selected.'),
          ),
        );
        return;
      }

      setState(() {
        _customExportDirectory = directoryPath;
        _exportDestination = ExportDestination.customFolder;
        _exportStatusMessage = 'Export destination set to $directoryPath';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export folder selected successfully.'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Export folder picker failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export folder selection failed: $error'),
        ),
      );
    }
  }

  Future<void> _scanExportedMedia(String outputPath) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _mediaScannerChannel.invokeMethod<void>('scanFile', {
        'path': outputPath,
      });
    } catch (_) {
      // Export already succeeded; indexing is best-effort only.
    }
  }


  String _exportBitrateValue() {
    return switch (_exportBitrate) {
      ExportBitrate.low => '6M',
      ExportBitrate.medium => '12M',
      ExportBitrate.high => '24M',
    };
  }

  String _buildExportScaleFilter() {
    return switch (_exportResolution) {
      ExportResolution.source => '',
      ExportResolution.p1080 =>
        'scale=w=1920:h=1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2',
      ExportResolution.p720 =>
        'scale=w=1280:h=720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2',
    };
  }

  Future<String?> _writeExportOverlayAsset(String assetPath, String fileName) async {
    try {
      final asset = await rootBundle.load(assetPath);
      final outputFile =
          File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');
      await outputFile.writeAsBytes(
        asset.buffer.asUint8List(),
        flush: true,
      );
      return outputFile.path;
    } catch (_) {
      return null;
    }
  }

  // Maps the manual core grading sliders into FFmpeg's eq filter values.
  String _buildExportVideoFilter() {
    final brightnessValue = ColorGrading.exportBrightnessValue(_brightness);
    final contrastValue = ColorGrading.exportContrastValue(_contrast);
    final saturationValue = ColorGrading.exportSaturationValue(_saturation);
    final warmthTint = ColorGrading.warmthTintChannelScale(
      warmth: _warmth,
      tint: _tint,
    );
    final presetFilters = _buildExportPresetFilters();
    final isNeutralBrightness = brightnessValue.abs() < 0.01;
    final isNeutralContrast = (contrastValue - 1.0).abs() < 0.01;
    final isNeutralSaturation = (saturationValue - 1.0).abs() < 0.01;
    final isNeutralWarmthTint =
        (warmthTint.red - 1.0).abs() < 0.001 &&
        (warmthTint.green - 1.0).abs() < 0.001 &&
        (warmthTint.blue - 1.0).abs() < 0.001;

    if (isNeutralBrightness &&
        isNeutralContrast &&
        isNeutralSaturation &&
        isNeutralWarmthTint &&
        presetFilters.isEmpty) {
      return '';
    }

    final filters = <String>[];

    if (!isNeutralBrightness || !isNeutralContrast || !isNeutralSaturation) {
      filters.add(
        'eq='
        'brightness=${brightnessValue.toStringAsFixed(3)}:'
        'contrast=${contrastValue.toStringAsFixed(3)}:'
        'saturation=${saturationValue.toStringAsFixed(3)}',
      );
    }

    if (!isNeutralWarmthTint) {
      filters.add(
        'colorchannelmixer='
        'rr=${warmthTint.red.toStringAsFixed(3)}:'
        'gg=${warmthTint.green.toStringAsFixed(3)}:'
        'bb=${warmthTint.blue.toStringAsFixed(3)}',
      );
    }

    filters.addAll(presetFilters);
    return filters.join(',');
  }

  String? get _activePresetOverlayAssetPath {
    if (!_showPresetOverlay || _presetStrength <= 0.01) {
      return null;
    }

    return switch (_selectedPresetIndex) {
      0 => 'assets/overlays/balanced_overlay_preview.png',
      1 => 'assets/overlays/cinematic_overlay_preview.png',
      3 => 'assets/overlays/low_light_overlay_preview.png',
      2 => 'assets/overlays/vivid_overlay_preview.png',
      _ => null,
    };
  }

  String _buildExportCommand({
    required String inputPath,
    required String outputPath,
    required String videoFilter,
    String? overlayPath,
  }) {
    final escapedInput = inputPath.replaceAll('"', r'\"');
    final escapedOutput = outputPath.replaceAll('"', r'\"');
    final scaleFilter = _buildExportScaleFilter();
    final bitrate = _exportBitrateValue();
    final formatFlags = switch (_exportFormat) {
      ExportFormat.mp4 => '-movflags +faststart',
      ExportFormat.mov => '',
    };

    if (overlayPath == null || overlayPath.isEmpty) {
      final filters = <String>[];
      if (videoFilter.isNotEmpty) {
        filters.add(videoFilter);
      }
      if (scaleFilter.isNotEmpty) {
        filters.add(scaleFilter);
      }
      final filterArgument = filters.isEmpty
          ? ''
          : '-vf "${filters.join(',').replaceAll('"', r'\"')}" ';
      return '-y -i "$escapedInput" $filterArgument-c:v libx264 -preset ultrafast -threads 2 -b:v $bitrate -maxrate $bitrate -bufsize $bitrate -pix_fmt yuv420p -colorspace bt709 -color_primaries bt709 -color_trc bt709 -c:a aac $formatFlags "$escapedOutput"';
    }

    final escapedOverlay = overlayPath.replaceAll('"', r'\"');
    final overlayAlpha = (0.35 + (_presetStrength * 0.55)).clamp(0.35, 0.90);
    final baseFilters = <String>[];
    if (videoFilter.isNotEmpty) {
      baseFilters.add(videoFilter);
    }
    if (scaleFilter.isNotEmpty) {
      baseFilters.add(scaleFilter);
    }
    final baseFilter = baseFilters.isEmpty ? 'null' : baseFilters.join(',');
    final filterComplex =
        '[0:v]$baseFilter[base];'
        '[1:v][base]scale2ref=w=iw:h=ih[overlay][base2];'
        '[overlay]format=rgba,colorchannelmixer=aa=${overlayAlpha.toStringAsFixed(3)}[overlaya];'
        '[base2][overlaya]overlay=0:0:format=auto[vout]';

    return '-y -i "$escapedInput" -loop 1 -i "$escapedOverlay" -filter_complex "${filterComplex.replaceAll('"', r'\"')}" -map "[vout]" -map 0:a? -shortest -c:v libx264 -preset ultrafast -threads 2 -b:v $bitrate -maxrate $bitrate -bufsize $bitrate -pix_fmt yuv420p -colorspace bt709 -color_primaries bt709 -color_trc bt709 -c:a aac $formatFlags "$escapedOutput"';
  }

  // Export-driven parity: preset identity comes from overlays rather than a
  // second FFmpeg grading pass, which was causing color drift away from preview.
  List<String> _buildExportPresetFilters() {
    return const [];
  }

  Future<void> _exportVideo() async {
    final messenger = ScaffoldMessenger.of(context);
    final selectedClip = _selectedClip;
    final inputPath = selectedClip?.filePath;

    if (inputPath == null || inputPath.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Import and select a video before exporting.'),
        ),
      );
      return;
    }

    if (_isExporting) {
      return;
    }

    try {
      final outputPath = _buildExportOutputPath(inputPath);
      final outputDirectory = Directory(File(outputPath).parent.path);
      await outputDirectory.create(recursive: true);

      final videoFilter = _buildExportVideoFilter();
      String? overlayPath;

      final activeOverlayAssetPath = _activePresetOverlayAssetPath;
      if (activeOverlayAssetPath != null) {
        overlayPath = await _writeExportOverlayAsset(
          activeOverlayAssetPath,
          switch (_selectedPresetIndex) {
            0 => 'balanced_overlay_export.png',
            1 => 'cinematic_overlay_export.png',
            3 => 'low_light_overlay_export.png',
            _ => 'vivid_overlay_export.png',
          },
        );
      }

      final command = _buildExportCommand(
        inputPath: inputPath,
        outputPath: outputPath,
        videoFilter: videoFilter,
        overlayPath: overlayPath,
      );

      debugPrint('Export input path: $inputPath');
      debugPrint('Export output path: $outputPath');
      debugPrint('Export command: $command');

      setState(() {
        _isExporting = true;
        _lastExportSucceeded = false;
        _exportStatusMessage = 'Exporting ${selectedClip!.title}...';
        _lastExportPath = outputPath;
      });

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!mounted) {
        return;
      }

      if (ReturnCode.isSuccess(returnCode)) {
        final finalOutputPath = outputPath;
        await _scanExportedMedia(outputPath);
        setState(() {
          _lastExportSucceeded = true;
          _exportStatusMessage = 'Export complete.';
          _lastExportPath = finalOutputPath;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Exported video to $finalOutputPath'),
          ),
        );
      } else if (ReturnCode.isCancel(returnCode)) {
        setState(() {
          _lastExportSucceeded = false;
          _exportStatusMessage = 'Export canceled.';
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Export was canceled.'),
          ),
        );
      } else {
        final logs = await session.getLogsAsString();
        setState(() {
          _lastExportSucceeded = false;
          _exportStatusMessage = logs.isEmpty
              ? 'Export failed.'
              : 'Export failed. Check debug logs for FFmpeg details.';
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Export failed.${logs.isEmpty ? '' : ' Check logs in debug console.'}',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Export failed before FFmpeg could finish: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }
      setState(() {
        _lastExportSucceeded = false;
        _exportStatusMessage = 'Export failed before FFmpeg could finish.';
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed before FFmpeg could finish: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
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
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.40,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/patterns/white_star_pattern.png'),
                          repeat: ImageRepeat.repeat,
                          alignment: Alignment.topLeft,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
                    child: const Text('Nova.IO Video Enhancement'),
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
          : _previewErrorMessage != null
          ? PreviewErrorMessage(message: _previewErrorMessage!)
          : selectedClip != null
          ? CustomPaint(
              painter: FramePainter(
                accent: selectedClip.accent,
                emphasizeEnhancement: _showAfter,
              ),
            )
          : const EmptyPreviewMessage(),
      effectOverlays: [
        if (_showAfter && _activePresetOverlayAssetPath != null)
          IgnorePointer(
            child: Opacity(
              opacity: (0.35 + (_presetStrength * 0.55)).clamp(0.35, 0.90),
              child: Image.asset(
                _activePresetOverlayAssetPath!,
                fit: BoxFit.cover,
              ),
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
                        _syncExportFileName();
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
    return ColorGrading.buildAdjustmentMatrix(
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      warmth: _warmth,
      tint: _tint,
      showAfter: _showAfter,
    );
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
          _previewErrorMessage = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isPreviewLoading = true;
        _previewErrorMessage = null;
      });
    }

    final controller = VideoPlayerController.file(File(filePath));
    await previousController?.dispose();

    try {
      await controller.initialize().timeout(const Duration(seconds: 12));
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
        _previewErrorMessage = null;
        _showPreviewControls = true;
      });
    } catch (error) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _isPreviewLoading = false;
          _previewErrorMessage =
              'Preview could not load for this clip. Try an MP4 (H.264/AAC) video.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preview load failed: $error'),
          ),
        );
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
      showPresetOverlay: _showPresetOverlay,
      onTogglePresetOverlay: (value) {
        setState(() {
          _showPresetOverlay = value;
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
            const SizedBox(height: 14),
            const Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _exportFileNameController,
              decoration: InputDecoration(
                labelText: 'File Name',
                hintText: 'Export file name',
                helperText: 'Extension is added automatically.',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFF22324D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFF22324D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFF63B3FF)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildExportDropdown<ExportResolution>(
                    label: 'Resolution',
                    value: _exportResolution,
                    items: const [
                      DropdownMenuItem(
                        value: ExportResolution.source,
                        child: Text('Source'),
                      ),
                      DropdownMenuItem(
                        value: ExportResolution.p1080,
                        child: Text('1080p'),
                      ),
                      DropdownMenuItem(
                        value: ExportResolution.p720,
                        child: Text('720p'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _exportResolution = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildExportDropdown<ExportFormat>(
                    label: 'Format',
                    value: _exportFormat,
                    items: const [
                      DropdownMenuItem(
                        value: ExportFormat.mp4,
                        child: Text('MP4'),
                      ),
                      DropdownMenuItem(
                        value: ExportFormat.mov,
                        child: Text('MOV'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _exportFormat = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildExportDropdown<ExportBitrate>(
                    label: 'Bitrate',
                    value: _exportBitrate,
                    items: const [
                      DropdownMenuItem(
                        value: ExportBitrate.low,
                        child: Text('6 Mbps'),
                      ),
                      DropdownMenuItem(
                        value: ExportBitrate.medium,
                        child: Text('12 Mbps'),
                      ),
                      DropdownMenuItem(
                        value: ExportBitrate.high,
                        child: Text('24 Mbps'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _exportBitrate = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Destination',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildExportDestinationChip(
                  label: 'Original Folder',
                  destination: ExportDestination.originalFolder,
                ),
                _buildExportDestinationChip(
                  label: _customExportDirectory == null
                      ? 'Choose Folder'
                      : 'Selected Folder',
                  destination: ExportDestination.customFolder,
                  onTap: _pickExportDirectory,
                ),
              ],
            ),
            if (_exportDestination == ExportDestination.customFolder &&
                _customExportDirectory != null) ...[
              const SizedBox(height: 10),
              Text(
                _customExportDirectory!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isExporting
                      ? const Color(0xFF63B3FF)
                      : _lastExportSucceeded
                      ? const Color(0xFF68E0C1)
                      : const Color(0xFF22324D),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isExporting
                            ? Icons.sync_rounded
                            : _lastExportSucceeded
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 18,
                        color: _isExporting
                            ? const Color(0xFF63B3FF)
                            : _lastExportSucceeded
                            ? const Color(0xFF68E0C1)
                            : Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isExporting ? 'Export Status' : 'Last Export',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _exportStatusMessage,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  if (_lastExportPath != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _lastExportPath!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isExporting ? null : _exportVideo,
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_done_rounded),
              label: Text(_isExporting ? 'Exporting Video' : 'Export Video'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF22324D)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF121D31),
          borderRadius: BorderRadius.circular(16),
          iconEnabledColor: Colors.white70,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          items: items,
          onChanged: onChanged,
          selectedItemBuilder: (context) {
            return items.map((item) {
              final child = item.child;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: child,
                      ),
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildExportDestinationChip({
    required String label,
    required ExportDestination destination,
    VoidCallback? onTap,
  }) {
    final isSelected = _exportDestination == destination;
    return InkWell(
      onTap: onTap ??
          () {
        setState(() {
          _exportDestination = destination;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? Colors.white70 : const Color(0xFF22324D),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

}


