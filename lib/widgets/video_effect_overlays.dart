import 'package:flutter/material.dart';

import '../helpers/analyzer_helper.dart';

class BalancedPresetOverlay extends StatelessWidget {
  const BalancedPresetOverlay({super.key, required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _fullLinear(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.09 * strength),
            Colors.white.withValues(alpha: 0.02 * strength),
            const Color(0xFF09111F).withValues(alpha: 0.08 * strength),
          ],
          stops: const [0, 0.48, 1],
        ),
        _fullRadial(
          center: Alignment.center,
          radius: 1.06,
          colors: [
            Colors.transparent,
            const Color(0xFF09111F).withValues(alpha: 0.05 * strength),
          ],
          stops: const [0.76, 1],
        ),
        _radialSpot(const Alignment(0, -0.82), 220, 82, [
          Colors.white.withValues(alpha: 0.10 * strength),
          Colors.white.withValues(alpha: 0.03 * strength),
          Colors.transparent,
        ], const [0, 0.42, 1]),
        _radialSpot(const Alignment(0, -0.54), 260, 120, [
          Colors.white.withValues(alpha: 0.06 * strength),
          Colors.white.withValues(alpha: 0.015 * strength),
          Colors.transparent,
        ], const [0, 0.36, 1]),
      ],
    );
  }
}

class CinematicPresetOverlay extends StatelessWidget {
  const CinematicPresetOverlay({super.key, required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _fullLinear(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFB27A).withValues(alpha: 0.14 * strength),
            Colors.transparent,
            const Color(0xFF060A14).withValues(alpha: 0.34 * strength),
          ],
          stops: const [0, 0.36, 1],
        ),
        _fullRadial(
          center: Alignment.center,
          radius: 1.02,
          colors: [
            Colors.transparent,
            const Color(0xFF060A14).withValues(alpha: 0.26 * strength),
          ],
          stops: const [0.54, 1],
        ),
        _radialSpot(const Alignment(0, -0.78), 260, 96, [
          const Color(0xFFFFC38E).withValues(alpha: 0.14 * strength),
          const Color(0xFFFFC38E).withValues(alpha: 0.05 * strength),
          Colors.transparent,
        ], const [0, 0.42, 1]),
        _radialSpot(const Alignment(0, -0.18), 300, 180, [
          const Color(0xFFFFD2A8).withValues(alpha: 0.08 * strength),
          const Color(0xFFFFD2A8).withValues(alpha: 0.025 * strength),
          Colors.transparent,
        ], const [0, 0.34, 1]),
      ],
    );
  }
}

class VividPresetOverlay extends StatelessWidget {
  const VividPresetOverlay({super.key, required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _fullLinear(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF78D9FF).withValues(alpha: 0.13 * strength),
            Colors.transparent,
            const Color(0xFF6EFFC6).withValues(alpha: 0.12 * strength),
          ],
          stops: const [0, 0.50, 1],
        ),
        _fullRadial(
          center: Alignment.topCenter,
          radius: 1.12,
          colors: [
            Colors.white.withValues(alpha: 0.07 * strength),
            Colors.transparent,
            const Color(0xFF06101A).withValues(alpha: 0.10 * strength),
          ],
          stops: const [0, 0.42, 1],
        ),
        _radialSpot(const Alignment(0.58, -0.36), 180, 120, [
          Colors.white.withValues(alpha: 0.08 * strength),
          const Color(0xFF95F6FF).withValues(alpha: 0.03 * strength),
          Colors.transparent,
        ], const [0, 0.34, 1]),
      ],
    );
  }
}

class LowLightPresetOverlay extends StatelessWidget {
  const LowLightPresetOverlay({super.key, required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _fullLinear(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.05 * strength),
            const Color(0xFF8FC8FF).withValues(alpha: 0.08 * strength),
            Colors.transparent,
          ],
          stops: const [0, 0.30, 1],
        ),
        _fullRadial(
          center: Alignment.center,
          radius: 1.14,
          colors: [
            Colors.white.withValues(alpha: 0.09 * strength),
            Colors.transparent,
            const Color(0xFF09111F).withValues(alpha: 0.08 * strength),
          ],
          stops: const [0, 0.48, 1],
        ),
        _radialSpot(const Alignment(0, -0.10), 280, 180, [
          Colors.white.withValues(alpha: 0.08 * strength),
          const Color(0xFFB6DCFF).withValues(alpha: 0.03 * strength),
          Colors.transparent,
        ], const [0, 0.34, 1]),
      ],
    );
  }
}

class SelectiveColorOverlay extends StatelessWidget {
  const SelectiveColorOverlay({
    super.key,
    required this.presetIndex,
    required this.strength,
  });

  final int presetIndex;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return switch (presetIndex) {
      0 => Stack(children: [
          _radialSpot(const Alignment(-0.72, -0.28), 180, 180, [
            const Color(0xFF7FD9FF).withValues(alpha: 0.030 * strength),
            Colors.transparent,
          ], const [0, 1]),
          _radialSpot(const Alignment(0.66, 0.20), 180, 180, [
            const Color(0xFF9AE7C1).withValues(alpha: 0.026 * strength),
            Colors.transparent,
          ], const [0, 1]),
        ]),
      1 => Stack(children: [
          _radialSpot(const Alignment(-0.62, 0.36), 240, 220, [
            const Color(0xFF5EA1D6).withValues(alpha: 0.070 * strength),
            Colors.transparent,
          ], const [0, 1]),
          _radialSpot(const Alignment(0.48, -0.54), 220, 180, [
            const Color(0xFFFFA66E).withValues(alpha: 0.058 * strength),
            Colors.transparent,
          ], const [0, 1]),
        ]),
      2 => Stack(children: [
          _radialSpot(const Alignment(-0.58, -0.10), 220, 220, [
            const Color(0xFF6BCBFF).withValues(alpha: 0.090 * strength),
            Colors.transparent,
          ], const [0, 1]),
          _radialSpot(const Alignment(0.62, 0.14), 220, 220, [
            const Color(0xFF56F0B5).withValues(alpha: 0.082 * strength),
            Colors.transparent,
          ], const [0, 1]),
        ]),
      _ => Stack(children: [
          _radialSpot(const Alignment(-0.60, 0.28), 260, 220, [
            const Color(0xFF7AB7E9).withValues(alpha: 0.060 * strength),
            Colors.transparent,
          ], const [0, 1]),
          _radialSpot(const Alignment(0.44, -0.42), 170, 150, [
            Colors.white.withValues(alpha: 0.030 * strength),
            Colors.transparent,
          ], const [0, 1]),
        ]),
    };
  }
}

class SceneAwareOverlay extends StatelessWidget {
  const SceneAwareOverlay({
    super.key,
    required this.sceneFlavor,
    required this.strength,
  });

  final SceneFlavor sceneFlavor;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return switch (sceneFlavor) {
      SceneFlavor.portrait => _radialSpot(const Alignment(0, -0.12), 240, 260, [
          const Color(0xFFFFC8A6).withValues(alpha: 0.045 * strength),
          Colors.transparent,
        ], const [0, 1]),
      SceneFlavor.water => _radialSpot(const Alignment(-0.46, -0.16), 280, 260, [
          const Color(0xFF6ECEFF).withValues(alpha: 0.060 * strength),
          Colors.transparent,
        ], const [0, 1]),
      SceneFlavor.nature => _radialSpot(const Alignment(0.34, 0.02), 280, 260, [
          const Color(0xFF74E5A0).withValues(alpha: 0.050 * strength),
          Colors.transparent,
        ], const [0, 1]),
      SceneFlavor.night => _fullLinear(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A2D52).withValues(alpha: 0.045 * strength),
            Colors.transparent,
            const Color(0xFF060A14).withValues(alpha: 0.060 * strength),
          ],
          stops: const [0, 0.42, 1],
        ),
      SceneFlavor.urban => _linearSpot(const Alignment(-0.22, 0.10), 320, 220, [
          const Color(0xFF6AA9FF).withValues(alpha: 0.028 * strength),
          Colors.transparent,
          const Color(0xFFFFB077).withValues(alpha: 0.028 * strength),
        ]),
      SceneFlavor.animation => _radialSpot(const Alignment(0.12, -0.06), 320, 260, [
          const Color(0xFF8FE7FF).withValues(alpha: 0.070 * strength),
          const Color(0xFF8C7CFF).withValues(alpha: 0.055 * strength),
          Colors.transparent,
        ], const [0, 0.42, 1]),
      SceneFlavor.socialEdit => _linearSpot(const Alignment(0.18, -0.02), 340, 240, [
          const Color(0xFF67D8FF).withValues(alpha: 0.040 * strength),
          Colors.transparent,
          const Color(0xFFFF92C8).withValues(alpha: 0.040 * strength),
        ]),
      SceneFlavor.neutral => const SizedBox.shrink(),
    };
  }
}

Widget _fullLinear({
  required Alignment begin,
  required Alignment end,
  required List<Color> colors,
  List<double>? stops,
}) => DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(begin: begin, end: end, colors: colors, stops: stops),
  ),
);

Widget _fullRadial({
  required Alignment center,
  required double radius,
  required List<Color> colors,
  required List<double> stops,
}) => DecoratedBox(
  decoration: BoxDecoration(
    gradient: RadialGradient(center: center, radius: radius, colors: colors, stops: stops),
  ),
);

Widget _radialSpot(Alignment alignment, double width, double height, List<Color> colors, List<double> stops) =>
    Align(
      alignment: alignment,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: RadialGradient(colors: colors, stops: stops),
        ),
      ),
    );

Widget _linearSpot(Alignment alignment, double width, double height, List<Color> colors) => Align(
  alignment: alignment,
  child: Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: colors),
    ),
  ),
);
