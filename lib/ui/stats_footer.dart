import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/providers.dart';
import '../domain/models.dart';
import 'theme.dart';

class StatsFooter extends ConsumerWidget {
  const StatsFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(resultProvider);
    final rules = ref.watch(rulesProvider);
    final counts = result.countsPerRuleId;
    final total = counts.values.fold<int>(0, (sum, n) => sum + n);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Total: ',
                style: AppTextStyles.ui(12, color: AppColors.muted),
              ),
              const SizedBox(width: 4),
              _OdometerTotal(value: total),
            ],
          ),
          const SizedBox(height: 8),
          _CoverageBar(rules: rules, counts: counts, total: total),
          if (total == 0) ...[
            const SizedBox(height: 4),
            Text(
              'No matches yet',
              style: AppTextStyles.ui(11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _OdometerTotal extends StatelessWidget {
  final int value;

  const _OdometerTotal({required this.value});

  @override
  Widget build(BuildContext context) {
    final digits = value.toString();
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final char in digits.split(''))
            SizedBox(
              width: 14,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, -0.4),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: Text(
                  char,
                  key: ValueKey(char),
                  style: AppTextStyles.mono(14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverageBar extends StatelessWidget {
  final List<Rule> rules;
  final Map<String, int> counts;
  final int total;

  const _CoverageBar({
    required this.rules,
    required this.counts,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSegments =
        rules.where((r) => (counts[r.id] ?? 0) > 0).toList();

    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.outline,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (total == 0 || constraints.maxWidth == 0) {
              return const SizedBox.shrink();
            }
            return Row(
              children: [
                for (final rule in visibleSegments)
                  _AnimatedSegment(
                    width: constraints.maxWidth,
                    count: counts[rule.id] ?? 0,
                    total: total,
                    color: AppColors.rulePalette[
                        rule.colorIndex % AppColors.rulePalette.length],
                    tooltip:
                        '${rule.pattern} → ${rule.replacement}: ${counts[rule.id]}',
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedSegment extends StatelessWidget {
  final double width;
  final int count;
  final int total;
  final Color color;
  final String tooltip;

  const _AnimatedSegment({
    required this.width,
    required this.count,
    required this.total,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      tween: Tween(begin: 0, end: count / total),
      builder: (context, value, _) => Tooltip(
        message: tooltip,
        child: Container(
          width: width * value,
          height: 8,
          color: color,
        ),
      ),
    );
  }
}
