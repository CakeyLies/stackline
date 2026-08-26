import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stackline/state/calculator_controller.dart';
import 'package:stackline/ui/functions_screen.dart';
import 'package:stackline/ui/keypad.dart';

/// The step/expression display can show text identical to a keypad button
/// (e.g. the digit "1") — scope to the real Keypad so `find.text` can't be
/// ambiguous, matching the same hazard already handled in
/// programs_controller_test.dart.
Finder _key(String label) =>
    find.descendant(of: find.byType(Keypad), matching: find.text(label));

void main() {
  testWidgets(
    'build x^2 + 1 through the real keypad in symbolic mode, save, survive a restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = CalculatorController(prefs);

      await tester.pumpWidget(
        MaterialApp(home: FunctionsListScreen(controller: controller)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'SqPlus1');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Not editing yet -- keypad taps must not reach the symbolic engine.
      expect(controller.isSymbolicEditing, isFalse);

      await tester.tap(find.text('Edit'));
      await tester.pump();
      expect(controller.isSymbolicEditing, isTrue);

      // x
      await tester.tap(find.byKey(const Key('pushVariableChip')));
      await tester.pump();
      expect(controller.functions.xDisplay, 'x');

      // x^2
      await tester.tap(_key('x²'));
      await tester.pump();
      expect(controller.functions.xDisplay, 'x^2');

      // + 1
      await tester.tap(_key('1'));
      await tester.pump();
      await tester.tap(_key('+'));
      await tester.pump();
      expect(controller.functions.xDisplay, 'x^2 + 1');

      await tester.tap(find.text('Stop editing'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pump();

      expect(controller.functions.saved, hasLength(1));
      expect(controller.functions.saved.single.name, 'SqPlus1');
      expect(
        controller.functions.saved.single.body.toDisplayString(),
        'x^2 + 1',
      );

      // Simulate an app restart: fresh controller, same (mocked) persisted
      // SharedPreferences backend.
      final prefs2 = await SharedPreferences.getInstance();
      final controller2 = CalculatorController(prefs2);

      expect(controller2.functions.saved, hasLength(1));
      final reloaded = controller2.functions.saved.single;
      expect(reloaded.name, 'SqPlus1');
      expect(reloaded.body.toDisplayString(), 'x^2 + 1');
      expect(reloaded.body.eval(3), 10); // 3^2 + 1 = 10
    },
  );

  testWidgets(
    'factorial/percent are rejected with an error, not silently dropped',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = CalculatorController(prefs);

      await tester.pumpWidget(
        MaterialApp(home: FunctionsListScreen(controller: controller)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bad');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.tap(_key('5'));
      await tester.pump();
      // Shift to reach n! (factorial is x²'s shift-variant on the folded
      // layout).
      await tester.tap(_key('SHIFT'));
      await tester.pump();
      await tester.tap(_key('n!'));
      await tester.pump();

      expect(controller.functions.error, isNotNull);
      expect(controller.functions.error, contains('n!'));
    },
  );

  testWidgets('the x chip is a no-op while not editing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = CalculatorController(prefs);

    await tester.pumpWidget(
      MaterialApp(home: FunctionsListScreen(controller: controller)),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Idle');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(controller.isSymbolicEditing, isFalse);
    await tester.tap(find.byKey(const Key('pushVariableChip')));
    await tester.pump();

    // Unchanged: still the placeholder body, no stack mutation occurred.
    expect(controller.functions.xDisplay, '0');
  });
}
