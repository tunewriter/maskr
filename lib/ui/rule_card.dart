import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/providers.dart';
import '../domain/models.dart';
import 'theme.dart';

class RuleCard extends ConsumerStatefulWidget {
  final Rule rule;
  final int count;
  final int maxCountAcrossRules;

  const RuleCard({
    super.key,
    required this.rule,
    required this.count,
    required this.maxCountAcrossRules,
  });

  @override
  ConsumerState<RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends ConsumerState<RuleCard> {
  late final TextEditingController _source;
  late final TextEditingController _target;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _source = TextEditingController(text: widget.rule.pattern);
    _target = TextEditingController(text: widget.rule.replacement);
  }

  @override
  void didUpdateWidget(RuleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule.pattern != widget.rule.pattern &&
        _source.text != widget.rule.pattern) {
      _source.text = widget.rule.pattern;
    }
    if (oldWidget.rule.replacement != widget.rule.replacement &&
        _target.text != widget.rule.replacement) {
      _target.text = widget.rule.replacement;
    }
  }

  @override
  void dispose() {
    _source.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;
    final color =
        AppColors.rulePalette[rule.colorIndex % AppColors.rulePalette.length];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        clipBehavior: Clip.hardEdge,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hovered ? AppColors.primary45 : AppColors.outline,
          ),
          boxShadow: _hovered
              ? const [
                  BoxShadow(
                    color: Color(0x30000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Opacity(
          opacity: rule.enabled ? 1 : 0.65,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Enable/disable rule',
                      icon: Icon(
                        rule.enabled ? Icons.toggle_on : Icons.toggle_off,
                        size: 20,
                        color:
                            rule.enabled ? AppColors.primary : AppColors.muted,
                      ),
                      hoverColor: const Color(0x0FFFFFFF),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: () => ref
                          .read(rulesProvider.notifier)
                          .toggleEnabled(rule.id),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: _RuleField(
                        controller: _source,
                        hint: rule.pattern.isEmpty ? 'empty' : 'Find',
                        onChanged: (value) => ref
                            .read(rulesProvider.notifier)
                            .updatePattern(rule.id, value),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(Icons.arrow_forward,
                          size: 12, color: AppColors.muted),
                    ),
                    Expanded(
                      child: _RuleField(
                        controller: _target,
                        hint: 'Replace',
                        onChanged: (value) => ref
                            .read(rulesProvider.notifier)
                            .updateReplacement(rule.id, value),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _MiniToggle(
                      active: rule.caseSensitive,
                      label: 'Aa',
                      tooltip: 'Match case',
                      onTap: () => ref
                          .read(rulesProvider.notifier)
                          .toggleCaseSensitive(rule.id),
                    ),
                    const SizedBox(width: 3),
                    _MiniToggle(
                      active: rule.wholeWord,
                      label: 'ab|',
                      tooltip: 'Whole words only',
                      onTap: () => ref
                          .read(rulesProvider.notifier)
                          .toggleWholeWord(rule.id),
                    ),
                    const SizedBox(width: 0),
                    // Fixed slot for the count chip so the row doesn't shift
                    // when it appears/disappears.
                    SizedBox(
                      width: 44,
                      child: widget.count > 0
                          ? Align(
                              alignment: Alignment.centerRight,
                              child: _CountChip(
                                count: widget.count,
                                color: color,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    // Destructive action: only visible (and clickable) on hover.
                    IgnorePointer(
                      ignoring: !_hovered,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 140),
                        opacity: _hovered ? 1 : 0,
                        child: IconButton(
                          tooltip: 'Delete rule',
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 17,
                            color: Color(0xFFE85D75),
                          ),
                          hoverColor: const Color(0x33E85D75),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 26, minHeight: 26),
                          onPressed: () => ref
                              .read(rulesProvider.notifier)
                              .deleteRule(rule.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Opacity(
                  opacity: 1,
                  child: _OccurrenceBar(
                    color: color,
                    fraction: widget.maxCountAcrossRules == 0
                        ? 0
                        : widget.count / widget.maxCountAcrossRules,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _RuleField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_RuleField> createState() => _RuleFieldState();
}

class _RuleFieldState extends State<_RuleField> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0x66062726) : const Color(0x44062726),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused ? AppColors.primary : Colors.transparent,
            ),
            boxShadow: _focused
                ? [BoxShadow(color: AppColors.primaryGlow, blurRadius: 10)]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            style: AppTextStyles.mono(14),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTextStyles.mono(14, color: AppColors.muted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              isDense: true,
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}

class _MiniToggle extends StatefulWidget {
  final bool active;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniToggle({
    required this.active,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_MiniToggle> createState() => _MiniToggleState();
}

class _MiniToggleState extends State<_MiniToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        label: widget.tooltip,
        button: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: widget.active
                    ? AppColors.secondary
                    : _hovered
                        ? const Color(0x66062726)
                        : const Color(0x22062726),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.transparent),
              ),
              child: Text(
                widget.label,
                style: AppTextStyles.mono(
                  10,
                  color: widget.active ? AppColors.text : AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OccurrenceBar extends StatelessWidget {
  final Color color;
  final double fraction;

  const _OccurrenceBar({required this.color, required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      color: AppColors.outline,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
        builder: (context, value, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

class _CountChip extends StatefulWidget {
  final int count;
  final Color color;

  const _CountChip({required this.count, required this.color});

  @override
  State<_CountChip> createState() => _CountChipState();
}

class _CountChipState extends State<_CountChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween:
          Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween:
          Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: 50,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant _CountChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${widget.count} matches in current text',
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '×${widget.count}',
            style: AppTextStyles.mono(12, color: widget.color),
          ),
        ),
      ),
    );
  }
}
