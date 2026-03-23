import 'package:flutter/material.dart';

class AnalysisCard extends StatelessWidget {
  const AnalysisCard({
    super.key,
    required this.summary,
    required this.sceneOptions,
    required this.isAnalyzing,
    required this.confidence,
    required this.signals,
    required this.onRunAnalysis,
    this.suggestedPresetTitle,
  });

  final String summary;
  final List<SceneTypeOption> sceneOptions;
  final bool isAnalyzing;
  final int confidence;
  final List<String> signals;
  final VoidCallback? onRunAnalysis;
  final String? suggestedPresetTitle;

  @override
  Widget build(BuildContext context) {
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
              summary,
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
            SceneTypeScroller(options: sceneOptions),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: isAnalyzing ? null : confidence / 100,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  isAnalyzing ? 'Analyzing...' : '$confidence%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: signals
                  .map(
                    (signal) => InsightPill(
                      label: signal.split(':').first,
                      value: signal.contains(':')
                          ? signal.split(':').skip(1).join(':').trim()
                          : signal,
                    ),
                  )
                  .toList(),
            ),
            if (suggestedPresetTitle != null) ...[
              const SizedBox(height: 18),
              Text(
                'Suggested preset: $suggestedPresetTitle',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRunAnalysis,
              icon: isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high_rounded),
              label: Text(isAnalyzing ? 'Analyzing Clip' : 'Run AI Pass'),
            ),
          ],
        ),
      ),
    );
  }
}

class SceneTypeOption {
  const SceneTypeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class SceneTypeScroller extends StatelessWidget {
  const SceneTypeScroller({
    super.key,
    required this.options,
  });

  final List<SceneTypeOption> options;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final option = options[index];
              return _SceneChip(
                label: option.label,
                selected: option.selected,
                onTap: option.onTap,
              );
            },
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
}

class InsightPill extends StatelessWidget {
  const InsightPill({
    super.key,
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

class _SceneChip extends StatelessWidget {
  const _SceneChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
