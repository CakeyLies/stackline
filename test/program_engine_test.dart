import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stackline/engine/engine.dart';
import 'package:stackline/engine/program_engine.dart';
import 'package:stackline/model/opcode.dart';
import 'package:stackline/model/program.dart';

void main() {
  group('ProgramEngine', () {
    test('straight-line program: 2 ENTER 3 + = 5', () {
      final engine = CalculatorEngine();
      final program = Program(
        name: 'add',
        steps: const [
          ProgramStep(Opcode.digit, operand: 2),
          ProgramStep(Opcode.enter),
          ProgramStep(Opcode.digit, operand: 3),
          ProgramStep(Opcode.add),
        ],
      );

      ProgramEngine(engine).run(program);

      expect(engine.x, Decimal.parse('5'));
    });

    test('GTO loop: sum 1..5 into register 0', () {
      final engine = CalculatorEngine();
      // LBL 1: register 1 = counter (starts at register 1's initial value 0)
      // reg0 = running sum, reg1 = counter
      // 00 LBL 01
      // 01 RCL 01        (counter)
      // 02 1
      // 03 +             (counter+1)
      // 04 STO 01        (save counter)
      // 05 RCL 00        (sum)
      // 06 RCL 01        (+counter)
      // 07 +
      // 08 STO 00        (save sum)
      // 09 RCL 01
      // 10 5
      // 11 X>Y? (X=5 literal > Y=counter -> keep looping)
      // 12 GTO 01
      // 13 RCL 00        (leave sum in X)
      final program = Program(
        name: 'sum1to5',
        steps: const [
          ProgramStep(Opcode.lbl, operand: 1),
          ProgramStep(Opcode.recall, operand: 1),
          ProgramStep(Opcode.digit, operand: 1),
          ProgramStep(Opcode.add),
          ProgramStep(Opcode.store, operand: 1),
          ProgramStep(Opcode.recall, operand: 0),
          ProgramStep(Opcode.recall, operand: 1),
          ProgramStep(Opcode.add),
          ProgramStep(Opcode.store, operand: 0),
          ProgramStep(Opcode.recall, operand: 1),
          ProgramStep(Opcode.digit, operand: 5),
          ProgramStep(Opcode.xGtY),
          ProgramStep(Opcode.gto, operand: 1),
          ProgramStep(Opcode.recall, operand: 0),
        ],
      );

      ProgramEngine(engine).run(program);

      expect(engine.x, Decimal.parse('15'));
    });

    test('GSB/RTN: call a subroutine that doubles X', () {
      final engine = CalculatorEngine();
      // 00 3
      // 01 ENTER          (commit the 3 so the subroutine's digit below
      //                    starts a fresh number instead of appending)
      // 02 GSB 10
      // 03 GTO 20  (skip past the subroutine, so RTN in it is reached first)
      // ...
      // 10 LBL 10
      // 11 2
      // 12 *
      // 13 RTN
      // 20 LBL 20
      final program = Program(
        name: 'double',
        steps: const [
          ProgramStep(Opcode.digit, operand: 3),
          ProgramStep(Opcode.enter),
          ProgramStep(Opcode.gsb, operand: 10),
          ProgramStep(Opcode.gto, operand: 20),
          ProgramStep(Opcode.lbl, operand: 10),
          ProgramStep(Opcode.digit, operand: 2),
          ProgramStep(Opcode.multiply),
          ProgramStep(Opcode.rtn),
          ProgramStep(Opcode.lbl, operand: 20),
        ],
      );

      ProgramEngine(engine).run(program);

      expect(engine.x, Decimal.parse('6'));
    });

    test('false test skips exactly the next line', () {
      final engine = CalculatorEngine();
      // X starts at 0 -> xGt0 is false -> skip the "digit 9" line.
      final program = Program(
        name: 'skip',
        steps: const [
          ProgramStep(Opcode.xGt0),
          ProgramStep(Opcode.digit, operand: 9),
          ProgramStep(Opcode.digit, operand: 1),
        ],
      );

      ProgramEngine(engine).run(program);

      // "digit 9" is skipped; "digit 1" runs but a bare digit only touches
      // the in-progress entry, not the committed x — check entryText, the
      // same thing the LCD reads while typing.
      expect(engine.entryActive, isTrue);
      expect(engine.entryText, '1');
    });

    test('true test falls through to the next line', () {
      final engine = CalculatorEngine();
      engine.digit(5);
      final program = Program(
        name: 'fallthrough',
        steps: const [
          ProgramStep(Opcode.xGt0),
          ProgramStep(Opcode.digit, operand: 9),
        ],
      );

      ProgramEngine(engine).run(program);

      // The test's own _commitIfNeeded() commits the "5" into x (lifting it
      // to y), then "digit 9" starts a fresh, separate entry.
      expect(engine.y, Decimal.parse('5'));
      expect(engine.entryActive, isTrue);
      expect(engine.entryText, '9');
    });

    test('RTN with an empty call stack halts the program', () {
      final engine = CalculatorEngine();
      final program = Program(
        name: 'earlyReturn',
        steps: const [
          ProgramStep(Opcode.digit, operand: 1),
          ProgramStep(Opcode.rtn),
          ProgramStep(Opcode.digit, operand: 2), // never reached
        ],
      );

      ProgramEngine(engine).run(program);

      expect(engine.entryActive, isTrue);
      expect(engine.entryText, '1');
    });

    test('infinite loop is stopped by the max-steps guard', () {
      final engine = CalculatorEngine();
      final program = Program(
        name: 'forever',
        steps: const [
          ProgramStep(Opcode.lbl, operand: 1),
          ProgramStep(Opcode.gto, operand: 1),
        ],
      );

      expect(
        () => ProgramEngine(engine, maxSteps: 1000).run(program),
        throwsA(isA<CalcError>()),
      );
    });

    test('GTO to a missing label throws', () {
      final engine = CalculatorEngine();
      final program = Program(
        name: 'badJump',
        steps: const [ProgramStep(Opcode.gto, operand: 99)],
      );

      expect(() => ProgramEngine(engine).run(program), throwsA(isA<CalcError>()));
    });
  });
}
