class ColorGrading {
  static double exportBrightnessValue(double brightness) {
    return ((brightness - 50) / 100).clamp(-1.0, 1.0);
  }

  static double exportContrastValue(double contrast) {
    return (0.7 + (contrast / 100) * 0.9).clamp(0.0, 2.0);
  }

  static double exportSaturationValue(double saturation) {
    return (0.35 + (saturation / 100) * 1.3).clamp(0.0, 3.0);
  }

  static double exportWarmthValue(double warmth) {
    return ((warmth - 50) / 50).clamp(-1.0, 1.0);
  }

  static double exportTintValue(double tint) {
    return ((tint - 50) / 50).clamp(-1.0, 1.0);
  }

  static ({double red, double green, double blue}) warmthTintChannelScale({
    required double warmth,
    required double tint,
  }) {
    final warmthValue = exportWarmthValue(warmth);
    final tintValue = exportTintValue(tint);

    return (
      red: (1.0 + (warmthValue * 0.12) + (tintValue * 0.04)).clamp(0.75, 1.25),
      green: (1.0 - (tintValue * 0.08)).clamp(0.75, 1.25),
      blue: (1.0 - (warmthValue * 0.12) + (tintValue * 0.04)).clamp(0.75, 1.25),
    );
  }

  // Builds the preview matrix from the same core values export uses so the
  // manual grading path stays aligned across preview and FFmpeg.
  static List<double> buildAdjustmentMatrix({
    required double brightness,
    required double contrast,
    required double saturation,
    required double warmth,
    required double tint,
    required bool showAfter,
  }) {
    if (!showAfter) {
      return const [
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ];
    }

    final brightnessOffset = exportBrightnessValue(brightness) * 255;
    final contrastValue = exportContrastValue(contrast);
    final saturationValue = exportSaturationValue(saturation);
    final warmthTint = warmthTintChannelScale(
      warmth: warmth,
      tint: tint,
    );

    final contrastMatrix = createContrastMatrix(
      contrastValue,
      translate: 128 * (1 - contrastValue),
    );
    final saturationMatrix = createSaturationMatrix(saturationValue);
    final brightnessMatrix = createBrightnessMatrix(brightnessOffset);
    final warmthTintMatrix = createChannelScaleMatrix(
      red: warmthTint.red,
      green: warmthTint.green,
      blue: warmthTint.blue,
    );

    return multiplyColorMatrices(
      brightnessMatrix,
      multiplyColorMatrices(
        warmthTintMatrix,
        multiplyColorMatrices(
          saturationMatrix,
          contrastMatrix,
        ),
      ),
    );
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

  static List<double> createChannelScaleMatrix({
    required double red,
    required double green,
    required double blue,
  }) {
    return [
      red, 0, 0, 0, 0,
      0, green, 0, 0, 0,
      0, 0, blue, 0, 0,
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
