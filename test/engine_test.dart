import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stackline/engine/display.dart';
import 'package:stackline/engine/engine.dart';

void main() {
  group('arithmetic', () {
    test('2 ENTER 3 + = 5', () {
      final e = CalculatorEngine();
      e.digit(2);
      e.enter();
      e.digit(3);
      e.add();
      expect(e.x, Decimal.parse('5'));
    });

    test('stack lift on ENTER', () {
      final e = CalculatorEngine();
      e.digit(7);
      e.enter();
      e.digit(8);
      e.add();
      expect(e.x, Decimal.parse('15'));
      expect(e.y, Decimal.zero);
    });

    test('decimal exactness 0.1 + 0.2 = 0.3', () {
      final e = CalculatorEngine();
      e.digit(0);
      e.decimalPoint();
      e.digit(1);
      e.enter();
      e.digit(0);
      e.decimalPoint();
      e.digit(2);
      e.add();
      expect(e.x, Decimal.parse('0.3'));
    });

    test('division and multiplication chain', () {
      final e = CalculatorEngine();
      e.digit(6);
      e.enter();
      e.digit(2);
      e.divide();
      expect(e.x, Decimal.parse('3'));
      e.digit(4);
      e.multiply();
      expect(e.x, Decimal.parse('12'));
    });

    test('divide by zero sets error', () {
      final e = CalculatorEngine();
      e.digit(5);
      e.enter();
      e.digit(0);
      e.divide();
      expect(e.error, 'Divide by 0');
    });
  });

  group('unary', () {
    test('sqrt of 2', () {
      final e = CalculatorEngine();
      e.digit(2);
      e.sqrt();
      expect(e.x.toDouble(), closeTo(1.41421356, 1e-8));
    });

    test('sqrt of negative sets error', () {
      final e = CalculatorEngine();
      e.digit(4);
      e.changeSign();
      e.sqrt();
      expect(e.error, 'Invalid data');
    });

    test('factorial 5 = 120', () {
      final e = CalculatorEngine();
      e.digit(5);
      e.factorial();
      expect(e.x, Decimal.parse('120'));
    });

    test('sin 90 deg = 1', () {
      final e = CalculatorEngine();
      e.angleMode = AngleMode.deg;
      e.digit(9);
      e.digit(0);
      e.sin();
      expect(e.x, Decimal.parse('1'));
    });

    test('ln of 1 = 0', () {
      final e = CalculatorEngine();
      e.digit(1);
      e.ln();
      expect(e.x, Decimal.zero);
    });
  });

  group('stack ops', () {
    test('swapXY', () {
      final e = CalculatorEngine();
      e.digit(1);
      e.enter();
      e.digit(2);
      e.swapXY();
      expect(e.x, Decimal.parse('1'));
      expect(e.y, Decimal.parse('2'));
    });

    test('rollDown', () {
      final e = CalculatorEngine();
      e.digit(1);
      e.enter();
      e.digit(2);
      e.enter();
      e.digit(3);
      e.enter();
      e.digit(4);
      e.rollDown();
      expect(e.x, Decimal.parse('3'));
      expect(e.y, Decimal.parse('2'));
      expect(e.z, Decimal.parse('1'));
      expect(e.t, Decimal.parse('4'));
    });
  });

  group('memory', () {
    test('store and recall', () {
      final e = CalculatorEngine();
      e.digit(4);
      e.digit(2);
      e.store(1);
      e.clearX();
      expect(e.x, Decimal.zero);
      e.recall(1);
      expect(e.x, Decimal.parse('42'));
    });
  });

  group('conditional tests', () {
    test('x vs 0', () {
      final e = CalculatorEngine();
      e.digit(0);
      expect(e.testXEqual0(), isTrue);
      expect(e.testXNotEqual0(), isFalse);
      expect(e.testXGreaterOrEqual0(), isTrue);
      expect(e.testXLessOrEqual0(), isTrue);

      e.clearX();
      e.digit(5);
      expect(e.testXGreater0(), isTrue);
      expect(e.testXLess0(), isFalse);

      e.clearX();
      e.digit(5);
      e.changeSign();
      expect(e.testXLess0(), isTrue);
      expect(e.testXGreater0(), isFalse);
    });

    test('x vs y', () {
      final e = CalculatorEngine();
      e.digit(3);
      e.enter();
      e.digit(5);
      // y=3, x=5
      expect(e.testXGreaterY(), isTrue);
      expect(e.testXLessY(), isFalse);
      expect(e.testXEqualY(), isFalse);

      e.clearX();
      e.digit(3);
      expect(e.testXEqualY(), isTrue);
      expect(e.testXGreaterOrEqualY(), isTrue);
      expect(e.testXLessOrEqualY(), isTrue);
    });

    test('tests do not mutate the stack', () {
      final e = CalculatorEngine();
      e.digit(3);
      e.enter();
      e.digit(5);
      e.testXGreaterY();
      expect(e.x, Decimal.parse('5'));
      expect(e.y, Decimal.parse('3'));
    });

    test('tests commit pending entry first', () {
      final e = CalculatorEngine();
      e.digit(7);
      // entry is still "active" (not committed) here — the test must see it.
      expect(e.testXEqual0(), isFalse);
      expect(e.testXGreater0(), isTrue);
    });
  });

  group('formatting', () {
    test('FIX 4', () {
      expect(formatDecimal(Decimal.parse('5'), DisplayMode.fix, 4), '5.0000');
    });

    test('SCI 4', () {
      expect(
        formatDecimal(Decimal.parse('12345'), DisplayMode.sci, 4),
        '1.235e4',
      );
    });
  });
}
