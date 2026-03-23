class ToneCurveProfile {
  const ToneCurveProfile({
    required this.contrast,
    required this.blackLift,
    required this.shadowLift,
    required this.midtoneLift,
  });

  final double contrast;
  final double blackLift;
  final double shadowLift;
  final double midtoneLift;
}

class ColorGrading {
  static List<double> buildAdjustmentMatrix({
    required double brightness,
    required double contrast,
    required double saturation,
    required double warmth,
    required double tint,
    required double highlights,
    required double shadows,
    required bool showAfter,
    required double presetStrength,
    required int selectedPresetIndex,
    required double sceneTintShift,
    required double sceneBrightnessLift,
  }) {
    final brightnessOffset = (brightness - 50) * 2.2;
    final contrastValue = 0.7 + (contrast / 100) * 0.9;
    final saturationValue = 0.35 + (saturation / 100) * 1.3;
    final warmthShift = (warmth - 50) / 100 * 28;
    final tintShift = (tint - 50) / 100 * 20;
    final highlightsOffset = (50 - highlights) * 0.8;
    final shadowsOffset = (shadows - 50) * 0.7;
    final effectivePresetStrength = showAfter ? presetStrength : 0.0;
    final curve = presetToneCurve(
      strength: effectivePresetStrength,
      selectedPresetIndex: selectedPresetIndex,
      showAfter: showAfter,
    );
    final clarityBoost = switch (selectedPresetIndex) {
      0 when showAfter => 1.0 + (0.05 * effectivePresetStrength),
      2 when showAfter => 1.0 + (0.08 * effectivePresetStrength),
      _ => 1.0,
    };
    final cinematicFade =
        showAfter && selectedPresetIndex == 1 ? 10.0 * effectivePresetStrength : 0.0;
    final lowLightLift =
        showAfter && selectedPresetIndex == 3 ? 8.0 * effectivePresetStrength : 0.0;

    final contrastMatrix = createContrastMatrix(
      contrastValue,
      translate: 128 * (1 - contrastValue),
    );
    final saturationMatrix = createSaturationMatrix(saturationValue);
    final warmthMatrix = createWarmthMatrix(warmthShift);
    final tintMatrix = createTintMatrix(tintShift);
    final brightnessMatrix = createBrightnessMatrix(brightnessOffset);
    final clarityMatrix = createContrastMatrix(
      clarityBoost,
      translate: 128 * (1 - clarityBoost),
    );
    final fadeMatrix = createBrightnessMatrix(cinematicFade);
    final lowLightLiftMatrix = createBrightnessMatrix(lowLightLift);
    final highlightsMatrix = createBrightnessMatrix(highlightsOffset);
    final shadowsMatrix = createBrightnessMatrix(shadowsOffset);
    final sceneTintMatrix = createTintMatrix(sceneTintShift);
    final sceneBrightnessMatrix = createBrightnessMatrix(sceneBrightnessLift);
    final curveShadowLiftMatrix = createBrightnessMatrix(curve.shadowLift);
    final curveMidtoneMatrix = createBrightnessMatrix(curve.midtoneLift);
    final curveContrastMatrix = createContrastMatrix(
      curve.contrast,
      translate: 128 * (1 - curve.contrast) + curve.blackLift,
    );

    return multiplyColorMatrices(
      sceneBrightnessMatrix,
      multiplyColorMatrices(
        sceneTintMatrix,
        multiplyColorMatrices(
          curveShadowLiftMatrix,
          multiplyColorMatrices(
            curveMidtoneMatrix,
            multiplyColorMatrices(
              curveContrastMatrix,
              multiplyColorMatrices(
                highlightsMatrix,
                multiplyColorMatrices(
                  shadowsMatrix,
                  multiplyColorMatrices(
                    lowLightLiftMatrix,
                    multiplyColorMatrices(
                      fadeMatrix,
                      multiplyColorMatrices(
                        clarityMatrix,
                        multiplyColorMatrices(
                          brightnessMatrix,
                          multiplyColorMatrices(
                            tintMatrix,
                            multiplyColorMatrices(
                              warmthMatrix,
                              multiplyColorMatrices(
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

  static ToneCurveProfile presetToneCurve({
    required double strength,
    required int selectedPresetIndex,
    required bool showAfter,
  }) {
    return switch (selectedPresetIndex) {
      0 when showAfter => ToneCurveProfile(
          contrast: 1.0 + (0.04 * strength),
          blackLift: 2.0 * strength,
          shadowLift: 1.6 * strength,
          midtoneLift: 0.8 * strength,
        ),
      1 when showAfter => ToneCurveProfile(
          contrast: 1.0 + (0.08 * strength),
          blackLift: 7.5 * strength,
          shadowLift: 0.8 * strength,
          midtoneLift: -1.2 * strength,
        ),
      2 when showAfter => ToneCurveProfile(
          contrast: 1.0 + (0.09 * strength),
          blackLift: 0.5 * strength,
          shadowLift: -0.6 * strength,
          midtoneLift: 2.6 * strength,
        ),
      3 when showAfter => ToneCurveProfile(
          contrast: 1.0 + (0.02 * strength),
          blackLift: 5.0 * strength,
          shadowLift: 4.6 * strength,
          midtoneLift: 1.4 * strength,
        ),
      _ => const ToneCurveProfile(
          contrast: 1.0,
          blackLift: 0.0,
          shadowLift: 0.0,
          midtoneLift: 0.0,
        ),
    };
  }

  static List<double> createBrightnessMatrix(double offset) {
    return [
      1, 0, 0, 0, offset,
      0, 1, 0, 0, offset,
      0, 0, 1, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> createContrastMatrix(double value, {double translate = 0}) {
    return [
      value, 0, 0, 0, translate,
      0, value, 0, 0, translate,
      0, 0, value, 0, translate,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> createSaturationMatrix(double value) {
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

  static List<double> createWarmthMatrix(double shift) {
    return [
      1.0, 0, 0, 0, shift,
      0, 1.0, 0, 0, 0,
      0, 0, 1.0, 0, -shift,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> createTintMatrix(double shift) {
    return [
      1.0, 0, 0, 0, shift * 0.45,
      0, 1.0, 0, 0, -shift,
      0, 0, 1.0, 0, shift * 0.45,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> multiplyColorMatrices(List<double> a, List<double> b) {
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
}
