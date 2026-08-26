import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:stackline/model/expr.dart';

const _x = VarExpr();

void main() {
  group('eval', () {
    test('x^2 at x=3 is 9', () {
      final e = PowExpr(_x, const ConstExpr(2));
      expect(e.eval(3), 9);
    });

    test('sin(x) at x=pi/2 is 1', () {
      final e = SinExpr(_x);
      expect(e.eval(3.14159265358979 / 2), closeTo(1, 1e-9));
    });

    test('x + 1 at x=5 is 6', () {
      final e = AddExpr(_x, const ConstExpr(1));
      expect(e.eval(5), 6);
    });

    test('emergent reciprocal 1/x at x=4 is 0.25', () {
      final e = DivExpr(const ConstExpr(1), _x);
      expect(e.eval(4), 0.25);
    });

    test('emergent x√y (root) matches pow(y, 1/x)', () {
      // x√y = y^(1/x); with x=2 this is sqrt(y).
      final y = ConstExpr(9);
      final e = PowExpr(y, DivExpr(const ConstExpr(1), const ConstExpr(2)));
      expect(e.eval(0), closeTo(3, 1e-9));
    });
  });

  group('differentiate: power rule', () {
    test('d/dx[x^2] = 2x (numeric)', () {
      final f = PowExpr(_x, const ConstExpr(2));
      final df = f.differentiate().simplify();
      for (final x in [-3.0, -1.0, 0.0, 1.5, 4.0]) {
        expect(df.eval(x), closeTo(2 * x, 1e-6));
      }
    });

    test('d/dx[x^2] simplifies to the elementary form "2 * x"', () {
      final f = PowExpr(_x, const ConstExpr(2));
      final df = f.differentiate().simplify();
      expect(df.toDisplayString(), '2 * x');
    });

    test('d/dx[2^x] = ln(2) * 2^x (numeric, non-constant-exponent case)', () {
      final f = PowExpr(const ConstExpr(2), _x);
      final df = f.differentiate().simplify();
      for (final x in [-2.0, 0.0, 1.0, 3.0]) {
        final expected = math.log(2) * math.pow(2, x);
        expect(df.eval(x), closeTo(expected, 1e-6));
      }
    });

    test('d/dx[f(x)^g(x)] via x^x (both vary, numeric)', () {
      // d/dx[x^x] = x^x * (ln(x) + 1)
      final f = PowExpr(_x, _x);
      final df = f.differentiate().simplify();
      for (final x in [0.5, 1.0, 2.0, 3.5]) {
        final expected = math.pow(x, x) * (math.log(x) + 1);
        expect(df.eval(x), closeTo(expected, 1e-6));
      }
    });
  });

  group('differentiate: product rule', () {
    test('d/dx[x * sin(x)] = sin(x) + x*cos(x)', () {
      final f = MulExpr(_x, SinExpr(_x));
      final df = f.differentiate().simplify();
      for (final x in [-2.0, 0.0, 1.0, 2.5]) {
        final expected = math.sin(x) + x * math.cos(x);
        expect(df.eval(x), closeTo(expected, 1e-6));
      }
    });
  });

  group('differentiate: quotient rule', () {
    test('d/dx[x / (x+1)] = 1 / (x+1)^2', () {
      final f = DivExpr(_x, AddExpr(_x, const ConstExpr(1)));
      final df = f.differentiate().simplify();
      for (final x in [-5.0, -0.5, 2.0, 10.0]) {
        final expected = 1 / ((x + 1) * (x + 1));
        expect(df.eval(x), closeTo(expected, 1e-6));
      }
    });
  });

  group('differentiate: chain rule', () {
    test('d/dx[sin(x^2)] = cos(x^2) * 2x', () {
      final f = SinExpr(PowExpr(_x, const ConstExpr(2)));
      final df = f.differentiate().simplify();
      expect(df.toDisplayString(), 'cos(x^2) * 2 * x');
      for (final x in [-2.0, 0.0, 1.0, 3.0]) {
        final expected = math.cos(x * x) * 2 * x;
        expect(df.eval(x), closeTo(expected, 1e-6));
      }
    });
  });

  group('simplify: constant folding', () {
    test('2 + 3 folds to 5', () {
      final e = AddExpr(const ConstExpr(2), const ConstExpr(3));
      expect(e.simplify().toDisplayString(), '5');
    });

    test('x + 0 folds to x', () {
      final e = AddExpr(_x, const ConstExpr(0));
      expect(e.simplify().toDisplayString(), 'x');
    });

    test('x * 1 folds to x, x * 0 folds to 0', () {
      expect(MulExpr(_x, const ConstExpr(1)).simplify().toDisplayString(), 'x');
      expect(MulExpr(_x, const ConstExpr(0)).simplify().toDisplayString(), '0');
    });

    test('x^1 folds to x, x^0 folds to 1', () {
      expect(PowExpr(_x, const ConstExpr(1)).simplify().toDisplayString(), 'x');
      expect(PowExpr(_x, const ConstExpr(0)).simplify().toDisplayString(), '1');
    });

    test('double negation cancels', () {
      final e = NegExpr(NegExpr(_x));
      expect(e.simplify().toDisplayString(), 'x');
    });

    test('x^2 / x reduces via the u^v/u rewrite to x', () {
      final e = DivExpr(PowExpr(_x, const ConstExpr(2)), _x);
      expect(e.simplify().toDisplayString(), 'x');
    });

    test('2 * (x^2 / x) reduces to 2 * x', () {
      // The exact sub-shape the power-rule derivative produces: a
      // coefficient times a Div(Pow(u,v), u) node.
      final e = MulExpr(
        const ConstExpr(2),
        DivExpr(PowExpr(_x, const ConstExpr(2)), _x),
      );
      expect(e.simplify().toDisplayString(), '2 * x');
    });
  });

  group('toDisplayString precedence', () {
    test('x^2 + 1', () {
      expect(
        AddExpr(
          PowExpr(_x, const ConstExpr(2)),
          const ConstExpr(1),
        ).toDisplayString(),
        'x^2 + 1',
      );
    });

    test('(x + 1)^2 needs parens around the base', () {
      expect(
        PowExpr(
          AddExpr(_x, const ConstExpr(1)),
          const ConstExpr(2),
        ).toDisplayString(),
        '(x + 1)^2',
      );
    });

    test('-x^2 means -(x^2), no parens needed', () {
      expect(
        NegExpr(PowExpr(_x, const ConstExpr(2))).toDisplayString(),
        '-x^2',
      );
    });

    test('(-x)^2 needs parens since it differs from -x^2', () {
      expect(
        PowExpr(NegExpr(_x), const ConstExpr(2)).toDisplayString(),
        '(-x)^2',
      );
    });

    test('a - (b - c) needs parens on the right', () {
      final e = SubExpr(_x, SubExpr(const ConstExpr(1), const ConstExpr(2)));
      expect(e.toDisplayString(), 'x - (1 - 2)');
    });
  });

  group('JSON round-trip', () {
    test('a moderately complex expression survives toJson/fromJson', () {
      final original = AddExpr(
        MulExpr(const ConstExpr(3), PowExpr(_x, const ConstExpr(2))),
        SinExpr(DivExpr(_x, const ConstExpr(2))),
      );
      final restored = Expr.fromJson(original.toJson());
      expect(restored, original);
      for (final x in [-4.0, 0.0, 2.5, 7.0]) {
        expect(restored.eval(x), original.eval(x));
      }
    });

    test('every node type round-trips', () {
      final nodes = <Expr>[
        const ConstExpr(1.5),
        const VarExpr(),
        AddExpr(_x, const ConstExpr(1)),
        SubExpr(_x, const ConstExpr(1)),
        MulExpr(_x, const ConstExpr(1)),
        DivExpr(_x, const ConstExpr(1)),
        PowExpr(_x, const ConstExpr(1)),
        NegExpr(_x),
        SinExpr(_x),
        CosExpr(_x),
        TanExpr(_x),
        AsinExpr(_x),
        AcosExpr(_x),
        AtanExpr(_x),
        LnExpr(_x),
        Log10Expr(_x),
        ExpExpr(_x),
        SqrtExpr(_x),
      ];
      for (final node in nodes) {
        expect(
          Expr.fromJson(node.toJson()),
          node,
          reason: node.runtimeType.toString(),
        );
      }
    });
  });
}
