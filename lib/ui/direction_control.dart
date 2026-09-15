import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/providers.dart';
import '../domain/models.dart';
import 'theme.dart';

class DirectionControl extends ConsumerStatefulWidget {
  const DirectionControl({super.key});

  @override
  ConsumerState<DirectionControl> createState() => _DirectionControlState();
}

class _DirectionControlState extends ConsumerState<DirectionControl> {
  @override
  Widget build(BuildContext context) {
    final direction = ref.watch(directionProvider);

    return Semantics(
      label: 'Direction',
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: AppColors.outline),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Full inner size (excluding padding).
            final segWidth = constraints.maxWidth / 2;
            final thumbHeight = constraints.maxHeight;
            final alignX = direction == Direction.forward ? -1.0 : 1.0;

            return Stack(
              children: [
                AnimatedAlign(
                  alignment: Alignment(alignX, 0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: segWidth,
                    height: thumbHeight,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      _Segment(
                        label: 'Forward',
                        icon: Icons.arrow_forward,
                        selected: direction == Direction.forward,
                        onTap: () => ref
                            .read(directionProvider.notifier)
                            .state = Direction.forward,
                      ),
                      _Segment(
                        label: 'Reverse',
                        icon: Icons.arrow_back,
                        selected: direction == Direction.reverse,
                        onTap: () => ref
                            .read(directionProvider.notifier)
                            .state = Direction.reverse,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style:
                  AppTextStyles.ui(14, weight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
