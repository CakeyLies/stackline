import '../model/opcode.dart';
import '../model/program.dart';
import 'engine.dart';

/// Runs a [Program] against a [CalculatorEngine], HP-41-style:
/// - `LBL n` marks a jump target (a no-op at runtime, resolved ahead of time).
/// - `GTO n` jumps to `LBL n`.
/// - `GSB n` pushes a return address and jumps to `LBL n`; `RTN` pops it (or
///   halts the program if the call stack is empty, matching real HP-41
///   behavior where RTN at the top level just stops).
/// - A comparison test that evaluates false skips the next line; true falls
///   through normally. Loops are just `GTO` back to a label guarded by a
///   test — there's no dedicated loop opcode, matching the real HP-41.
///
/// Runs synchronously on the calling thread (no isolate), so a runaway loop
/// must not be able to hang the app — [maxSteps] and [maxCallDepth] are hard
/// guards that raise [CalcError] instead of looping forever.
class ProgramEngine {
  ProgramEngine(this.engine, {this.maxSteps = 100000, this.maxCallDepth = 200});

  final CalculatorEngine engine;
  final int maxSteps;
  final int maxCallDepth;

  /// Executes [program] from the start (or from `LBL startLabel` if given).
  void run(Program program, {int? startLabel}) {
    final labels = _indexLabels(program.steps);
    final callStack = <int>[];
    var pointer = startLabel == null ? 0 : _requireLabel(labels, startLabel);
    var stepsRun = 0;

    while (pointer < program.steps.length) {
      if (stepsRun++ > maxSteps) {
        throw const CalcError('Program too long');
      }
      final step = program.steps[pointer];
      final op = step.op;

      if (isTestOpcode(op)) {
        final passed = _evalTest(op);
        pointer += passed ? 1 : 2;
        continue;
      }

      switch (op) {
        case Opcode.lbl:
          pointer++;
        case Opcode.gto:
          pointer = _requireLabel(labels, step.operand!);
        case Opcode.gsb:
          if (callStack.length >= maxCallDepth) {
            throw const CalcError('GSB too deep');
          }
          callStack.add(pointer + 1);
          pointer = _requireLabel(labels, step.operand!);
        case Opcode.rtn:
          if (callStack.isEmpty) return;
          pointer = callStack.removeLast();
        default:
          _execute(op, step.operand);
          pointer++;
      }
    }
  }

  Map<int, int> _indexLabels(List<ProgramStep> steps) {
    final labels = <int, int>{};
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.op == Opcode.lbl) {
        labels[step.operand!] = i;
      }
    }
    return labels;
  }

  int _requireLabel(Map<int, int> labels, int n) {
    final index = labels[n];
    if (index == null) throw CalcError('No LBL $n');
    return index;
  }

  bool _evalTest(Opcode op) => switch (op) {
    Opcode.xEq0 => engine.testXEqual0(),
    Opcode.xNe0 => engine.testXNotEqual0(),
    Opcode.xGt0 => engine.testXGreater0(),
    Opcode.xLt0 => engine.testXLess0(),
    Opcode.xGe0 => engine.testXGreaterOrEqual0(),
    Opcode.xLe0 => engine.testXLessOrEqual0(),
    Opcode.xEqY => engine.testXEqualY(),
    Opcode.xNeY => engine.testXNotEqualY(),
    Opcode.xGtY => engine.testXGreaterY(),
    Opcode.xLtY => engine.testXLessY(),
    Opcode.xGeY => engine.testXGreaterOrEqualY(),
    Opcode.xLeY => engine.testXLessOrEqualY(),
    _ => throw StateError('$op is not a test opcode'),
  };

  void _execute(Opcode op, int? operand) {
    switch (op) {
      case Opcode.digit:
        engine.digit(operand!);
      case Opcode.decimalPoint:
        engine.decimalPoint();
      case Opcode.enterExponent:
        engine.enterExponent();
      case Opcode.changeSign:
        engine.changeSign();
      case Opcode.backspace:
        engine.backspace();
      case Opcode.enter:
        engine.enter();
      case Opcode.swapXY:
        engine.swapXY();
      case Opcode.rollDown:
        engine.rollDown();
      case Opcode.rollUp:
        engine.rollUp();
      case Opcode.lastX:
        engine.lastXRecall();
      case Opcode.clearX:
        engine.clearX();
      case Opcode.clearAll:
        engine.clearAll();
      case Opcode.store:
        engine.store(operand!);
      case Opcode.recall:
        engine.recall(operand!);
      case Opcode.pi:
        engine.pushPi();
      case Opcode.eConst:
        engine.pushE();
      case Opcode.add:
        engine.add();
      case Opcode.subtract:
        engine.subtract();
      case Opcode.multiply:
        engine.multiply();
      case Opcode.divide:
        engine.divide();
      case Opcode.power:
        engine.power();
      case Opcode.root:
        engine.root();
      case Opcode.percent:
        engine.percent();
      case Opcode.percentChange:
        engine.percentChange();
      case Opcode.reciprocal:
        engine.reciprocal();
      case Opcode.sqrt:
        engine.sqrt();
      case Opcode.square:
        engine.square();
      case Opcode.log10:
        engine.log10();
      case Opcode.ln:
        engine.ln();
      case Opcode.tenToX:
        engine.tenToX();
      case Opcode.eToX:
        engine.eToX();
      case Opcode.sin:
        engine.sin();
      case Opcode.cos:
        engine.cos();
      case Opcode.tan:
        engine.tan();
      case Opcode.asin:
        engine.asin();
      case Opcode.acos:
        engine.acos();
      case Opcode.atan:
        engine.atan();
      case Opcode.factorial:
        engine.factorial();
      case Opcode.lbl:
      case Opcode.gto:
      case Opcode.gsb:
      case Opcode.rtn:
      case Opcode.xEq0:
      case Opcode.xNe0:
      case Opcode.xGt0:
      case Opcode.xLt0:
      case Opcode.xGe0:
      case Opcode.xLe0:
      case Opcode.xEqY:
      case Opcode.xNeY:
      case Opcode.xGtY:
      case Opcode.xLtY:
      case Opcode.xGeY:
      case Opcode.xLeY:
        throw StateError('$op handled elsewhere');
    }
  }
}
