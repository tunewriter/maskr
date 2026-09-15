import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maskr/app.dart';
import 'package:maskr/application/providers.dart';

/// Finds a [TextField] by the hint text it was given.
Finder _fieldWithHint(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
    );

void main() {
  late Directory storageDir;

  setUp(() {
    // Point persistence at a throwaway directory so tests never read or write
    // the real ~/.masktext_*.json files.
    storageDir = Directory.systemTemp.createTempSync('maskr_test');
  });

  tearDown(() {
    if (storageDir.existsSync()) storageDir.deleteSync(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageDirProvider.overrideWithValue(storageDir.path)],
        child: const MaskrApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the input and output panes', (tester) async {
    await pumpApp(tester);

    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Output'), findsOneWidget);
  });

  testWidgets('masks input text using a rule', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add rule'));
    await tester.pumpAndSettle();

    await tester.enterText(_fieldWithHint('empty'), 'Jonathan');
    await tester.enterText(_fieldWithHint('Replace'), 'Name_J');
    await tester.pumpAndSettle();

    await tester.enterText(
      _fieldWithHint('Paste your text here…'),
      'Jonathan met Bern',
    );
    await tester.pumpAndSettle();

    expect(find.text('Name_J met Bern'), findsOneWidget);
  });

  testWidgets('restores the exact original when reversing masked text',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add rule'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldWithHint('empty'), 'Jonathan');
    await tester.enterText(_fieldWithHint('Replace'), 'Name_J');
    await tester.pumpAndSettle();

    // Mask lowercase input; the rule is case-insensitive.
    await tester.enterText(
      _fieldWithHint('Paste your text here…'),
      'jonathan left',
    );
    await tester.pumpAndSettle();
    expect(find.text('Name_J left'), findsOneWidget);

    // Flip to Reverse, then paste the masked text back in.
    await tester.tap(find.text('Reverse'));
    await tester.pumpAndSettle();
    await tester.enterText(
      _fieldWithHint('Paste your text here…'),
      'Name_J left',
    );
    await tester.pumpAndSettle();

    // The original casing is recovered, which the stateless reverse cannot do.
    expect(find.text('jonathan left'), findsOneWidget);
  });
}
