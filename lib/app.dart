import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/providers.dart';
import 'domain/models.dart';
import 'domain/replace_engine.dart';
import 'ui/main_window.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ProviderScope(child: MaskrApp()));
}

class MaskrApp extends ConsumerStatefulWidget {
  const MaskrApp({super.key});

  @override
  ConsumerState<MaskrApp> createState() => _MaskrAppState();
}

class _MaskrAppState extends ConsumerState<MaskrApp> {
  Timer? _debounceTimer;

  @override
  Widget build(BuildContext context) {
    ref.listen(rawInputProvider, (prev, next) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 20), () {
        ref.read(debouncedInputProvider.notifier).state = next;
        final direction = ref.read(directionProvider);
        // Re-sort rules by how often they matched in the new input
        final result = apply(next, ref.read(rulesProvider), direction);
        if (direction == Direction.forward && result.events.isNotEmpty) {
          // Remember the last pass that actually masked something, so that
          // reversing the masked text can restore the exact original.
          ref.read(lastMaskedResultProvider.notifier).state = result;
        }
        ref
            .read(rulesProvider.notifier)
            .reorderByMatchCounts(result.countsPerRuleId);
      });
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maskr',
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      home: MainWindow(),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
