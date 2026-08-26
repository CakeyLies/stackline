import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stackline/model/opcode.dart';
import 'package:stackline/model/program.dart';
import 'package:stackline/state/calculator_controller.dart';
import 'package:stackline/ui/keypad.dart';
import 'package:stackline/ui/programs_screen.dart';

/// The step list can show a mnemonic identical to a keypad button (e.g. a
/// recorded "1" step next to the "1" digit key) — scope to the real Keypad
/// so repeated digits in a program don't make `find.text` ambiguous.
Finder _key(String label) =>
    find.descendant(of: find.byType(Keypad), matching: find.text(label));

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

  testWidgets(
    'author a real GTO loop through the UI (mini-keypad + real keypad) and run it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = CalculatorController(prefs);

      await tester.pumpWidget(
        MaterialApp(home: ProgramsListScreen(controller: controller)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Countdown');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record'));
      await tester.pump();

      // 3 ENTER: X=3, Y=3 (committed via ENTER, so the loop body's digit
      // entry below starts fresh instead of appending).
      await tester.tap(_key('3'));
      await tester.pump();
      await tester.tap(_key('ENTER'));
      await tester.pump();

      // LBL 01 via the control-flow mini-keypad + two real digit taps.
      await tester.tap(find.text(opcodeLabel(Opcode.lbl)));
      await tester.pump();
      await tester.tap(_key('0'));
      await tester.pump();
      await tester.tap(_key('1'));
      await tester.pump();

      // 1 -  (subtract 1 from X each pass)
      await tester.tap(_key('1'));
      await tester.pump();
      await tester.tap(_key('−'));
      await tester.pump();

      // X>0? then GTO 01 -- both from the control-flow mini-keypad.
      await tester.tap(find.text(opcodeLabel(Opcode.xGt0)));
      await tester.pump();
      await tester.tap(find.text(opcodeLabel(Opcode.gto)));
      await tester.pump();
      await tester.tap(_key('0'));
      await tester.pump();
      await tester.tap(_key('1'));
      await tester.pump();

      await tester.tap(find.text('Stop recording'));
      await tester.pump();

      expect(controller.programs.draftSteps, const [
        ProgramStep(Opcode.digit, operand: 3),
        ProgramStep(Opcode.enter),
        ProgramStep(Opcode.lbl, operand: 1),
        ProgramStep(Opcode.digit, operand: 1),
        ProgramStep(Opcode.subtract),
        ProgramStep(Opcode.xGt0),
        ProgramStep(Opcode.gto, operand: 1),
      ]);

      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pump();

      final error = controller.programs.run(controller.programs.saved.single);
      expect(error, isNull);
      expect(controller.engine.x, Decimal.zero);
    },
  );

  testWidgets('selecting a step inserts new keys after it, not at the end', (
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
    await tester.enterText(find.byType(TextField), 'Insert');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Record'));
    await tester.pump();

    await tester.tap(_key('1'));
    await tester.pump();
    await tester.tap(_key('2'));
    await tester.pump();

    expect(controller.programs.draftSteps, const [
      ProgramStep(Opcode.digit, operand: 1),
      ProgramStep(Opcode.digit, operand: 2),
    ]);

    // Select the first step ("01  1") and record a new key: it should land
    // between the two existing steps, not after the second one.
    controller.programs.selectStep(0);
    await tester.pump();

    await tester.tap(_key('9'));
    await tester.pump();

    expect(controller.programs.draftSteps, const [
      ProgramStep(Opcode.digit, operand: 1),
      ProgramStep(Opcode.digit, operand: 9),
      ProgramStep(Opcode.digit, operand: 2),
    ]);
  });
}
