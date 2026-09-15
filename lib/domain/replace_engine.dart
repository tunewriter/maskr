import 'models.dart';

/// Pure Dart engine for simultaneous, non-cascading literal text replacement.
/// Single left-to-right scan, longest match wins, tie broken by original list order.
/// Never interprets patterns as regex.
EngineResult apply(String input, List<Rule> rules, Direction direction) {
  // 1. Build effective rules: swap for reverse, drop disabled/empty patterns
  final effectiveRules = <_EffectiveRule>[];
  final warnings = <String>[];
  final seenPatterns = <String, String>{}; // lowercase -> ruleId
  final seenReplacements = <String, String>{}; // lowercase -> ruleId

  for (final rule in rules) {
    if (!rule.enabled) continue;
    final pattern = rule.pattern.trim();
    final replacement = rule.replacement.trim();
    if (pattern.isEmpty) continue;

    final effectivePattern =
        direction == Direction.reverse ? replacement : pattern;
    final effectiveReplacement =
        direction == Direction.reverse ? pattern : replacement;
    if (effectivePattern.isEmpty) continue;

    final effRule = _EffectiveRule(
      id: rule.id,
      pattern: effectivePattern,
      replacement: effectiveReplacement,
      caseSensitive: rule.caseSensitive,
      wholeWord: rule.wholeWord,
      colorIndex: rule.colorIndex,
    );
    effectiveRules.add(effRule);

    // Duplicate pattern warning
    final lowerPattern = effectivePattern.toLowerCase();
    if (seenPatterns.containsKey(lowerPattern)) {
      warnings.add(
        'Duplicate pattern "$effectivePattern" (case-insensitive) between rule '
        '"${seenPatterns[lowerPattern]}" and "${rule.id}".',
      );
    } else {
      seenPatterns[lowerPattern] = rule.id;
    }

    // Duplicate replacement warning
    final lowerReplacement = effectiveReplacement.toLowerCase();
    if (seenReplacements.containsKey(lowerReplacement)) {
      warnings.add(
        'Duplicate replacement "$effectiveReplacement" (case-insensitive) between '
        'rule "${seenReplacements[lowerReplacement]}" and "${rule.id}". Reverse '
        'direction would be ambiguous.',
      );
    } else {
      seenReplacements[lowerReplacement] = rule.id;
    }
  }

  // 2. Stable sort by pattern length descending (longest match first)
  // Stable sort preserves original order for ties.
  effectiveRules.sort((a, b) => b.pattern.length.compareTo(a.pattern.length));

  // 3. Single-pass scanner
  final outputBuffer = StringBuffer();
  final events = <MatchEvent>[];
  final counts = <String, int>{};
  for (final rule in effectiveRules) {
    counts[rule.id] = 0;
  }

  // Index rules by first character for quick skipping
  final index = <int, List<_EffectiveRule>>{};
  for (final rule in effectiveRules) {
    final firstChar = rule.caseSensitive
        ? rule.pattern.codeUnitAt(0)
        : rule.pattern.toLowerCase().codeUnitAt(0);
    index.putIfAbsent(firstChar, () => []).add(rule);
  }

  final wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);
  int i = 0;
  int outputPos = 0;

  while (i < input.length) {
    final currentChar = input.codeUnitAt(i);
    final lowerChar =
        String.fromCharCode(currentChar).toLowerCase().codeUnitAt(0);
    final candidates = <_EffectiveRule>{};
    if (index.containsKey(currentChar)) candidates.addAll(index[currentChar]!);
    if (currentChar != lowerChar && index.containsKey(lowerChar))
      candidates.addAll(index[lowerChar]!);
    if (candidates.isEmpty) candidates.addAll(effectiveRules);

    bool matched = false;
    for (final rule in candidates) {
      if (i + rule.pattern.length > input.length) continue;

      final substring = input.substring(i, i + rule.pattern.length);
      final match = rule.caseSensitive
          ? substring == rule.pattern
          : substring.toLowerCase() == rule.pattern.toLowerCase();

      if (!match) continue;

      // Whole-word check
      if (rule.wholeWord) {
        final patternStart = rule.pattern[0];
        final patternEnd = rule.pattern[rule.pattern.length - 1];
        final charBefore = i > 0 ? input[i - 1] : null;
        final charAfter = i + rule.pattern.length < input.length
            ? input[i + rule.pattern.length]
            : null;

        if (wordChar.hasMatch(patternStart) &&
            charBefore != null &&
            wordChar.hasMatch(charBefore)) {
          continue;
        }
        if (wordChar.hasMatch(patternEnd) &&
            charAfter != null &&
            wordChar.hasMatch(charAfter)) {
          continue;
        }
      }

      // Match! Emit replacement.
      outputBuffer.write(rule.replacement);
      if (rule.replacement.isNotEmpty) {
        events.add(
          MatchEvent(
            start: outputPos,
            end: outputPos + rule.replacement.length,
            ruleId: rule.id,
            originalText: substring,
          ),
        );
      }
      counts[rule.id] = (counts[rule.id] ?? 0) + 1;
      outputPos += rule.replacement.length;
      i += rule.pattern.length;
      matched = true;
      break; // longest match already selected
    }

    if (!matched) {
      outputBuffer.write(input[i]);
      outputPos++;
      i++;
    }
  }

  // 4. Roundtrip-risk warnings: check if any effective replacement appears in the input
  for (final rule in effectiveRules) {
    if (rule.replacement.isEmpty) continue;
    if (_matchesInInput(
      input,
      rule.replacement,
      rule.caseSensitive,
      rule.wholeWord,
      wordChar,
    )) {
      warnings.add(
        'Replacement "${rule.replacement}" (rule "${rule.id}") appears in the input. '
        'Reverse result may be incorrect.',
      );
    }
  }

  return EngineResult(
    outputText: outputBuffer.toString(),
    events: events,
    countsPerRuleId: counts,
    warnings: warnings,
  );
}

/// Rebuilds the exact original text from a forward [EngineResult].
///
/// The stateless reverse pass cannot recover the original casing of a
/// case-insensitive match — `jonathan` and `JONATHAN` both mask to the same
/// replacement — so reversing masked text is lossy. The forward pass records
/// the exact text each match replaced, which lets this invert it losslessly.
///
/// The returned [EngineResult] describes the restored text, with events
/// pointing at the restored matches so they can still be highlighted.
///
/// Rules whose replacement is empty emit no event, so text deleted by them
/// cannot be recovered.
EngineResult restore(EngineResult forward) {
  final buffer = StringBuffer();
  final events = <MatchEvent>[];
  var cursor = 0;
  var outputPos = 0;

  for (final event in forward.events) {
    if (event.start > cursor) {
      final gap = forward.outputText.substring(cursor, event.start);
      buffer.write(gap);
      outputPos += gap.length;
    }
    events.add(
      MatchEvent(
        start: outputPos,
        end: outputPos + event.originalText.length,
        ruleId: event.ruleId,
        originalText: event.originalText,
      ),
    );
    buffer.write(event.originalText);
    outputPos += event.originalText.length;
    cursor = event.end;
  }

  if (cursor < forward.outputText.length) {
    buffer.write(forward.outputText.substring(cursor));
  }

  return EngineResult(
    outputText: buffer.toString(),
    events: events,
    countsPerRuleId: forward.countsPerRuleId,
    warnings: forward.warnings,
  );
}

bool _matchesInInput(
  String input,
  String pattern,
  bool caseSensitive,
  bool wholeWord,
  RegExp wordChar,
) {
  for (int i = 0; i <= input.length - pattern.length; i++) {
    final sub = input.substring(i, i + pattern.length);
    final match = caseSensitive
        ? sub == pattern
        : sub.toLowerCase() == pattern.toLowerCase();
    if (!match) continue;

    if (wholeWord) {
      final patternStart = pattern[0];
      final patternEnd = pattern[pattern.length - 1];
      final charBefore = i > 0 ? input[i - 1] : null;
      final charAfter =
          i + pattern.length < input.length ? input[i + pattern.length] : null;
      if (wordChar.hasMatch(patternStart) &&
          charBefore != null &&
          wordChar.hasMatch(charBefore)) continue;
      if (wordChar.hasMatch(patternEnd) &&
          charAfter != null &&
          wordChar.hasMatch(charAfter)) continue;
    }
    return true;
  }
  return false;
}

class _EffectiveRule {
  final String id;
  final String pattern;
  final String replacement;
  final bool caseSensitive;
  final bool wholeWord;
  final int colorIndex;

  _EffectiveRule({
    required this.id,
    required this.pattern,
    required this.replacement,
    required this.caseSensitive,
    required this.wholeWord,
    required this.colorIndex,
  });
}
