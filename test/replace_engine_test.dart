import 'package:flutter_test/flutter_test.dart';
import 'package:maskr/domain/models.dart';
import 'package:maskr/domain/replace_engine.dart';

void main() {
  group('ReplaceEngine', () {
    test('Simultaneity: [A→B, B→C] on "A" ⇒ "B"', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'A',
          replacement: 'B',
          enabled: true,
          wholeWord: false,
        ),
        Rule(
          id: '2',
          pattern: 'B',
          replacement: 'C',
          enabled: true,
          wholeWord: false,
        ),
      ];
      final result = apply('A', rules, Direction.forward);
      expect(result.outputText, 'B');
    });

    test(
      'Case-insensitive by default: "Jonathan"→"Name_J" matches "JONATHAN"',
      () {
        final rules = [
          Rule(
            id: '1',
            pattern: 'Jonathan',
            replacement: 'Name_J',
            enabled: true,
            wholeWord: false,
          ),
        ];
        final result = apply('JONATHAN', rules, Direction.forward);
        expect(result.outputText, 'Name_J');
      },
    );

    test('Case-insensitive default: matches "jonathan"', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'Jonathan',
          replacement: 'Name_J',
          enabled: true,
          wholeWord: false,
        ),
      ];
      final result = apply('jonathan', rules, Direction.forward);
      expect(result.outputText, 'Name_J');
    });

    test('Case-sensitive override works', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'Jonathan',
          replacement: 'Name_J',
          enabled: true,
          caseSensitive: true,
          wholeWord: false,
        ),
      ];
      final result = apply('JONATHAN', rules, Direction.forward);
      expect(result.outputText, 'JONATHAN');
    });

    test('Whole-word by default: "Jan"→"X" does NOT touch "Januar"', () {
      final rules = [
        Rule(id: '1', pattern: 'Jan', replacement: 'X', enabled: true),
      ];
      final result = apply('Januar', rules, Direction.forward);
      expect(result.outputText, 'Januar');
    });

    test('Whole-word override: wholeWord=false allows partial match', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'Jan',
          replacement: 'X',
          enabled: true,
          wholeWord: false,
        ),
      ];
      final result = apply('Januar', rules, Direction.forward);
      expect(result.outputText, 'Xuar');
    });

    test('Longest match: [Anna→X, Annabella→Y] on "Annabella" ⇒ "Y"', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'Anna',
          replacement: 'X',
          enabled: true,
          wholeWord: false,
        ),
        Rule(
          id: '2',
          pattern: 'Annabella',
          replacement: 'Y',
          enabled: true,
          wholeWord: false,
        ),
      ];
      final result = apply('Annabella', rules, Direction.forward);
      expect(result.outputText, 'Y');
    });

    test(
      'Literal patterns: "Dr. Smith (Jr.)" with regex-special chars works',
      () {
        final rules = [
          Rule(
            id: '1',
            pattern: 'Dr. Smith (Jr.)',
            replacement: 'DOC',
            enabled: true,
            wholeWord: false,
          ),
        ];
        final result = apply(
          'Meet Dr. Smith (Jr.) today',
          rules,
          Direction.forward,
        );
        expect(result.outputText, 'Meet DOC today');
      },
    );

    test(
      'Adjacent matches: wholeWord=false, [Anna→X, Ben→Y] on "AnnaBen" ⇒ "XY"',
      () {
        final rules = [
          Rule(
            id: '1',
            pattern: 'Anna',
            replacement: 'X',
            enabled: true,
            wholeWord: false,
          ),
          Rule(
            id: '2',
            pattern: 'Ben',
            replacement: 'Y',
            enabled: true,
            wholeWord: false,
          ),
        ];
        final result = apply('AnnaBen', rules, Direction.forward);
        expect(result.outputText, 'XY');
      },
    );

    test('Counts are exact per rule', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'Anna',
          replacement: 'X',
          enabled: true,
          wholeWord: false,
        ),
        Rule(
          id: '2',
          pattern: 'Ben',
          replacement: 'Y',
          enabled: true,
          wholeWord: false,
        ),
      ];
      final result = apply('Anna and Ben and Anna', rules, Direction.forward);
      expect(result.countsPerRuleId['1'], 2);
      expect(result.countsPerRuleId['2'], 1);
    });

    test('Roundtrip: restore(apply(t, rules, forward)) == t', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'Jonathan',
          replacement: 'Name_J',
          enabled: true,
        ),
        Rule(
          id: '2',
          pattern: 'Annabella',
          replacement: 'Name_A',
          enabled: true,
        ),
        Rule(id: '3', pattern: 'Bern', replacement: 'Place_B', enabled: true),
      ];
      const input = 'Jonathan met Annabella in Bern. jonathan left.';
      final forwardResult = apply(input, rules, Direction.forward);
      final restored = restore(forwardResult);
      expect(restored.outputText, input);
    });

    test('restore highlights the matches it put back', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'Jonathan',
          replacement: 'Name_J',
          enabled: true,
        ),
      ];
      final forwardResult = apply('jonathan left', rules, Direction.forward);
      final restored = restore(forwardResult);
      expect(restored.outputText, 'jonathan left');
      expect(restored.events, hasLength(1));
      expect(restored.events.single.originalText, 'jonathan');
      expect(
        restored.outputText.substring(
          restored.events.single.start,
          restored.events.single.end,
        ),
        'jonathan',
      );
    });

    test('Stateless reverse is lossy for case-insensitive matches', () {
      // Documents why [restore] exists: reversing masked text cannot recover
      // the original casing, because the forward pass discarded it.
      final rules = [
        Rule(
          id: '1',
          pattern: 'Jonathan',
          replacement: 'Name_J',
          enabled: true,
        ),
      ];
      final forwardResult = apply('jonathan left', rules, Direction.forward);
      final reverseResult = apply(
        forwardResult.outputText,
        rules,
        Direction.reverse,
      );
      expect(reverseResult.outputText, 'Jonathan left');
    });

    test('Boundaries at very start/end of text behave correctly', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'word',
          replacement: 'X',
          enabled: true,
          wholeWord: true,
        ),
      ];
      final result = apply('word at start', rules, Direction.forward);
      expect(result.outputText, 'X at start');
      final resultEnd = apply('at end word', rules, Direction.forward);
      expect(resultEnd.outputText, 'at end X');
    });

    test('Empty replacement still counts match but no highlight event', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'remove',
          replacement: '',
          enabled: true,
          wholeWord: false,
        ),
      ];
      final result = apply('Please remove this', rules, Direction.forward);
      expect(result.outputText, 'Please  this');
      expect(result.events, isEmpty);
      expect(result.countsPerRuleId['1'], 1);
    });

    test('Rules with empty pattern are ignored', () {
      final rules = [
        Rule(id: '1', pattern: '   ', replacement: 'X', enabled: true),
        Rule(id: '2', pattern: 'hello', replacement: 'hi', enabled: true),
      ];
      final result = apply('hello', rules, Direction.forward);
      expect(result.outputText, 'hi');
    });

    test('Disabled rules are ignored', () {
      final rules = [
        Rule(id: '1', pattern: 'hello', replacement: 'hi', enabled: false),
      ];
      final result = apply('hello', rules, Direction.forward);
      expect(result.outputText, 'hello');
    });

    test('Tie-breaking: same length patterns use original list order', () {
      final rules = [
        Rule(
          id: '1',
          pattern: 'Anna',
          replacement: 'A',
          enabled: true,
          wholeWord: false,
        ),
        Rule(
          id: '2',
          pattern: 'Anne',
          replacement: 'B',
          enabled: true,
          wholeWord: false,
        ),
      ];
      final result = apply('Anna', rules, Direction.forward);
      expect(result.outputText, 'A');
    });

    test('Warnings: duplicate effective pattern', () {
      final rules = [
        Rule(id: '1', pattern: 'Hello', replacement: 'Hi', enabled: true),
        Rule(id: '2', pattern: 'hello', replacement: 'Hey', enabled: true),
      ];
      final result = apply('Hello world', rules, Direction.forward);
      expect(result.warnings.any((w) => w.contains('Duplicate pattern')), true);
    });

    test('Warnings: duplicate replacement', () {
      final rules = [
        Rule(id: '1', pattern: 'A', replacement: 'Same', enabled: true),
        Rule(id: '2', pattern: 'B', replacement: 'same', enabled: true),
      ];
      final result = apply('A B', rules, Direction.forward);
      expect(
        result.warnings.any((w) => w.contains('Duplicate replacement')),
        true,
      );
    });

    test('Warnings: roundtrip risk', () {
      final rules = [
        Rule(id: '1', pattern: 'Bern', replacement: 'Bern', enabled: true),
      ];
      final result = apply('Bern city', rules, Direction.forward);
      expect(
        result.warnings.any(
          (w) => w.contains('Reverse result may be incorrect'),
        ),
        true,
      );
    });
  });
}
