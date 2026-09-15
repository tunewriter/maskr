import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/providers.dart';
import 'profile_bar.dart';
import 'rule_card.dart';
import 'stats_footer.dart';
import 'theme.dart';

class RuleSidebar extends ConsumerWidget {
  const RuleSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider);
    final selectedProfileId = ref.watch(selectedProfileIdProvider);
    final counts = ref.watch(resultProvider.select((r) => r.countsPerRuleId));

    final maxCount = rules.fold<int>(0, (max, rule) {
      final c = counts[rule.id] ?? 0;
      return c > max ? c : max;
    });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.outline)),
      ),
      child: Column(
        children: [
          const ProfileBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Text(
                  'RULES (${rules.length})',
                  style: AppTextStyles.ui(13, weight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Swap source ↔ target in all rules',
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  hoverColor: const Color(0x0FFFFFFF),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(rulesProvider.notifier).swapAll(),
                ),
                IconButton(
                  tooltip: 'Add rule',
                  icon: const Icon(Icons.add, size: 18),
                  hoverColor: const Color(0x0FFFFFFF),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(rulesProvider.notifier).addRule(),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: slide,
                    child: child,
                  ),
                );
              },
              child: rules.isEmpty
                  ? Center(
                      key: ValueKey('rules_empty_$selectedProfileId'),
                      child: Text(
                        'No rules yet',
                        style: AppTextStyles.ui(13, color: AppColors.muted),
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey('rules_list_$selectedProfileId'),
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: rules.length,
                      itemBuilder: (context, index) {
                        final rule = rules[index];
                        return RuleCard(
                          rule: rule,
                          count: counts[rule.id] ?? 0,
                          maxCountAcrossRules: maxCount,
                        );
                      },
                    ),
            ),
          ),
          // Add-rule button in the empty space below the list.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => ref.read(rulesProvider.notifier).addRule(),
                icon: const Icon(Icons.add, size: 16, color: AppColors.muted),
                label: Text(
                  'Add rule',
                  style: AppTextStyles.ui(13, color: AppColors.muted),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.outline),
                  ),
                ),
              ),
            ),
          ),
          const StatsFooter(),
        ],
      ),
    );
  }
}
