import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/providers.dart';
import '../domain/models.dart';
import 'copy_button.dart';
import 'theme.dart';

class InputPane extends ConsumerStatefulWidget {
  const InputPane({super.key});

  @override
  ConsumerState<InputPane> createState() => _InputPaneState();
}

class _InputPaneState extends ConsumerState<InputPane> {
  late final TextEditingController _controller;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(rawInputProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Input',
                  style: AppTextStyles.ui(15, weight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: 'Clear input',
                icon: const Icon(Icons.clear, size: 18),
                hoverColor: const Color(0x0FFFFFFF),
                onPressed: () {
                  _controller.clear();
                  ref.read(rawInputProvider.notifier).state = '';
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Focus(
              onFocusChange: (value) => setState(() => _focused = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _focused ? AppColors.primary : AppColors.outline,
                  ),
                  boxShadow: _focused
                      ? [
                          BoxShadow(
                              color: AppColors.primaryGlow, blurRadius: 10)
                        ]
                      : null,
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: AppTextStyles.mono(14),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: 'Paste your text here…',
                    hintStyle: AppTextStyles.mono(14, color: AppColors.muted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: (value) {
                    ref.read(rawInputProvider.notifier).state = value;
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OutputPane extends ConsumerWidget {
  const OutputPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(resultProvider);
    final direction = ref.watch(directionProvider);
    final output = result.outputText;
    final events = result.events;
    final placeholder = direction == Direction.forward
        ? 'Masked text appears here as you type'
        : 'Restored text appears here as you type';

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Output',
                  style: AppTextStyles.ui(15, weight: FontWeight.w600)),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: direction == Direction.forward ? 0 : 0.5,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.arrow_forward,
                    size: 16, color: AppColors.muted),
              ),
              const Spacer(),
              CopyButton(text: output),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.outline),
              ),
              child: output.isEmpty
                  ? Center(
                      child: Text(
                        placeholder,
                        style: AppTextStyles.mono(14, color: AppColors.muted),
                      ),
                    )
                  : SingleChildScrollView(
                      child: _OutputText(
                        output: output,
                        events: events,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputText extends ConsumerWidget {
  final String output;
  final List<MatchEvent> events;

  const _OutputText({required this.output, required this.events});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider);
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final event in events) {
      if (event.start > lastEnd) {
        spans.add(TextSpan(text: output.substring(lastEnd, event.start)));
      }

      final rule = rules.firstWhere(
        (r) => r.id == event.ruleId,
        orElse: () => rules.isNotEmpty
            ? rules.first
            : Rule(
                id: '',
                pattern: '',
                replacement: '',
                colorIndex: 0,
              ),
      );
      final color =
          AppColors.rulePalette[rule.colorIndex % AppColors.rulePalette.length];

      spans.add(TextSpan(
        text: output.substring(event.start, event.end),
        style: TextStyle(
          backgroundColor: color.withValues(alpha: 0.35),
        ),
      ));
      lastEnd = event.end;
    }

    if (lastEnd < output.length) {
      spans.add(TextSpan(text: output.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: AppTextStyles.mono(14),
      cursorColor: AppColors.primary,
    );
  }
}
