import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stackline/model/opcode.dart';
import 'package:stackline/model/program.dart';
import 'package:stackline/state/calculator_controller.dart';
import 'package:stackline/ui/programs_screen.dart';

void main() {
  testWidgets(
    'record 2 ENTER 3 + from the real keypad, save, survive a restart, run',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = CalculatorController(prefs);

      await tester.pumpWidget(
        MaterialApp(home: ProgramsListScreen(controller: controller)),
      );
      await tester.pump();

      // Create a new program.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'AddTwo');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Now on ProgramEditorScreen. Start recording and tap real keys.
      expect(find.text('Record'), findsOneWidget);
      await tester.tap(find.text('Record'));
      await tester.pump();

      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('ENTER'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('+'));
      await tester.pump();

      await tester.tap(find.text('Stop recording'));
      await tester.pump();

      expect(controller.programs.draftSteps, const [
        ProgramStep(Opcode.digit, operand: 2),
        ProgramStep(Opcode.enter),
        ProgramStep(Opcode.digit, operand: 3),
        ProgramStep(Opcode.add),
      ]);

      // Recording must not have touched the live calculator engine at all.
      expect(controller.engine.x, Decimal.zero);
      expect(controller.engine.entryActive, isFalse);

      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pump();

      expect(controller.programs.saved, hasLength(1));
      expect(controller.programs.saved.single.name, 'AddTwo');

      // Simulate an app restart: fresh controller, same (mocked) persisted
      // SharedPreferences backend.
      final prefs2 = await SharedPreferences.getInstance();
      final controller2 = CalculatorController(prefs2);

      expect(controller2.programs.saved, hasLength(1));
      final reloaded = controller2.programs.saved.single;
      expect(reloaded.name, 'AddTwo');
      expect(reloaded.steps, controller.programs.saved.single.steps);

      final error = controller2.programs.run(reloaded);
      expect(error, isNull);
      expect(controller2.engine.x, Decimal.parse('5'));
    },
  );

  testWidgets('STO/RCL two-tap recording composes into one step each', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = CalculatorController(prefs);

    await tester.pumpWidget(
      MaterialApp(home: ProgramsListScreen(controller: controller)),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'StoRcl');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Record'));
    await tester.pump();

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('STO'));
    await tester.pump();
    await tester.tap(find.text('1'));
    await tester.pump();
    // RCL is the shift-variant of the same STO key in the folded (portrait)
    // layout used here — toggle SHIFT first so the key relabels to "RCL".
    await tester.tap(find.text('SHIFT'));
    await tester.pump();
    await tester.tap(find.text('RCL'));
    await tester.pump();
    await tester.tap(find.text('1'));
    await tester.pump();

    await tester.tap(find.text('Stop recording'));
    await tester.pump();

    expect(controller.programs.draftSteps, const [
      ProgramStep(Opcode.digit, operand: 5),
      ProgramStep(Opcode.store, operand: 1),
      ProgramStep(Opcode.recall, operand: 1),
    ]);

    // The live calculator's own pending flow must be untouched by recording.
    expect(controller.pending, isNull);
  });
}
