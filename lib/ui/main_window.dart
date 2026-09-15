import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../application/providers.dart';
import '../domain/models.dart';
import 'direction_control.dart';
import 'panes.dart';
import 'rule_sidebar.dart';
import 'theme.dart';
import 'warning_banner.dart';

class MainWindow extends ConsumerStatefulWidget {
  const MainWindow({super.key});

  @override
  ConsumerState<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends ConsumerState<MainWindow> {
  bool _warningsDismissed = false;
  bool _sidebarVisible = true;
  double _sidebarWidth = 375;

  static const double _minSidebarWidth = 300;
  static const double _maxSidebarWidth = 560;

  @override
  Widget build(BuildContext context) {
    final warnings = ref.watch(resultProvider.select((r) => r.warnings));
    final direction = ref.watch(directionProvider);

    // Re-show the banner whenever the warnings change.
    ref.listen(resultProvider.select((r) => r.warnings), (prev, next) {
      if ((prev?.join('|') ?? '') != (next?.join('|') ?? '')) {
        _warningsDismissed = false;
      }
    });

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true): () {
          ref.read(directionProvider.notifier).state =
              direction == Direction.forward
                  ? Direction.reverse
                  : Direction.forward;
        },
        SingleActivator(LogicalKeyboardKey.keyC, meta: true, shift: true): () {
          final outputText = ref.read(resultProvider).outputText;
          Clipboard.setData(ClipboardData(text: outputText));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied!'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Stack(
                children: [
                  // Main layout — always fills the whole area.
                  Column(
                    children: [
                      const _AppBar(),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(0.02, 0),
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
                                child: SizedBox.expand(
                                  key: ValueKey(direction),
                                  child: const Column(
                                    children: [
                                      Expanded(child: InputPane()),
                                      Expanded(child: OutputPane()),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_sidebarVisible) ...[
                              // Drag handle: resize the sidebar, double-click collapses it.
                              MouseRegion(
                                cursor: SystemMouseCursors.resizeLeftRight,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanUpdate: (details) {
                                    setState(() {
                                      _sidebarWidth =
                                          (_sidebarWidth - details.delta.dx)
                                              .clamp(_minSidebarWidth,
                                                  _maxSidebarWidth);
                                    });
                                  },
                                  onDoubleTap: () =>
                                      setState(() => _sidebarVisible = false),
                                  child: SizedBox(
                                    width: 6,
                                    child: Center(
                                      child: Container(
                                        width: 1,
                                        color: AppColors.outline,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: _sidebarWidth,
                                child: RuleSidebar(),
                              ),
                            ] else
                              // Collapsed: thin strip to bring the sidebar back.
                              Tooltip(
                                message: 'Show rules',
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        setState(() => _sidebarVisible = true),
                                    child: SizedBox(
                                      width: 22,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.chevron_left,
                                            size: 18,
                                            color: AppColors.muted,
                                          ),
                                          SizedBox(height: 6),
                                          RotatedBox(
                                            quarterTurns: 1,
                                            child: Text(
                                              'RULES',
                                              style: TextStyle(
                                                fontSize: 10,
                                                letterSpacing: 1.2,
                                                color: AppColors.muted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Warning banner as an overlay — sits above the content, pushes nothing.
                  if (warnings.isNotEmpty && !_warningsDismissed)
                    Positioned(
                      top: 70,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: WarningBanner(
                          warnings: warnings,
                          onDismiss: () =>
                              setState(() => _warningsDismissed = true),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        return Container(
          height: compact ? 108 : 60,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.outline)),
          ),
          child: compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: const [
                          _Title(),
                          Spacer(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const SizedBox(width: 280, child: DirectionControl()),
                  ],
                )
              : Stack(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: _Title(),
                      ),
                    ),
                    const Center(
                      child: SizedBox(
                        width: 300,
                        child: DirectionControl(),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.masks, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          'Maskr',
          style: AppTextStyles.ui(18, weight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: '100% offline – nothing leaves this device',
          child: const Icon(Icons.lock, size: 14, color: AppColors.muted),
        ),
      ],
    );
  }
}
