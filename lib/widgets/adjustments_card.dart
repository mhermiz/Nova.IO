import 'package:flutter/material.dart';

class AdjustmentControl {
  const AdjustmentControl({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
}

class AdjustmentsCard extends StatelessWidget {
  const AdjustmentsCard({
    super.key,
    required this.controls,
  });

  final List<AdjustmentControl> controls;

  @override
  Widget build(BuildContext context) {
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
            ...controls.map(
              (control) => AdjustmentSlider(
                label: control.label,
                value: control.value,
                onChanged: control.onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdjustmentSlider extends StatelessWidget {
  const AdjustmentSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
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
}
