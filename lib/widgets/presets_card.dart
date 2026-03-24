import 'package:flutter/material.dart';

import '../models/enhancement_preset.dart';
import 'adjustments_card.dart';

class PresetsCard extends StatelessWidget {
  const PresetsCard({
    super.key,
    required this.presets,
    required this.selectedPresetIndex,
    required this.onSelectPreset,
    required this.onClearPreset,
    required this.presetStrength,
    required this.onPresetStrengthChanged,
    required this.showPresetOverlay,
    required this.onTogglePresetOverlay,
  });

  final List<EnhancementPreset> presets;
  final int selectedPresetIndex;
  final ValueChanged<int> onSelectPreset;
  final VoidCallback onClearPreset;
  final double presetStrength;
  final ValueChanged<double> onPresetStrengthChanged;
  final bool showPresetOverlay;
  final ValueChanged<bool> onTogglePresetOverlay;

  @override
  Widget build(BuildContext context) {
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
            NoPresetOption(
              isSelected: selectedPresetIndex == -1,
              onTap: onClearPreset,
            ),
            const SizedBox(height: 12),
            ...List.generate(presets.length, (index) {
              final preset = presets[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == presets.length - 1 ? 0 : 12,
                ),
                child: PresetOptionTile(
                  preset: preset,
                  isSelected: index == selectedPresetIndex,
                  onTap: () => onSelectPreset(index),
                ),
              );
            }),
            if (selectedPresetIndex >= 0) ...[
              const SizedBox(height: 18),
              AdjustmentSlider(
                label: 'Preset Strength',
                value: presetStrength * 100,
                onChanged: onPresetStrengthChanged,
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: showPresetOverlay,
                onChanged: (value) => onTogglePresetOverlay(value ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Use Stylized Overlay',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Show overlay styling that is included in the preset.',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NoPresetOption extends StatelessWidget {
  const NoPresetOption({
    super.key,
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
              style: TextStyle(fontWeight: FontWeight.w700),
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
}

class PresetOptionTile extends StatelessWidget {
  const PresetOptionTile({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final EnhancementPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
    );
  }
}
