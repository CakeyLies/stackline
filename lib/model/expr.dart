import 'dart:convert';
import 'dart:math' as math;

/// A symbolic expression tree in one free variable, `x`.
///
/// This is a small, purpose-built AST — not a general CAS. It exists so
/// `differentiate()` can be a real symbolic derivative (the user explicitly
/// chose that over numeric approximation), while [eval] lets the same tree
/// drive graphing.
///
/// `eval` always treats trig arguments as **radians**, ignoring the
/// calculator's live DEG/RAD/GRAD mode — deliberately: respecting the live
/// mode would make `differentiate()` mathematically wrong in DEG mode (the
/// chain rule would need an extra `pi/180` factor), and would let a saved
/// function's meaning change if the angle mode is changed elsewhere later.
/// Every graphing calculator's function mode works the same way.
sealed class Expr {
  const Expr();

  /// Evaluates this expression at `x` (radians for any trig node).
  double eval(double x);

  /// The symbolic derivative with respect to `x`, unsimplified.
  Expr differentiate();

  /// A best-effort simplified form: constant folding and basic algebraic
  /// identities (`+0`, `*1`, `*0`, `^1`, `^0`, double negation, and the
  /// `u^v / u -> u^(v-1)` rewrite that keeps power-rule derivatives
  /// readable). Not a full CAS — good enough for readable output.
  Expr simplify();

  /// Precedence for parenthesization in [toDisplayString] — higher binds
  /// tighter. 1 = +/-, 2 = */÷, 3 = unary minus, 4 = ^, 5 = atomic
  /// (numbers, `x`, function calls, which are always unambiguous).
  int get precedence;

  /// Infix display form, e.g. `sin(x) + x^2`.
  String toDisplayString();

  Map<String, dynamic> toJson();

  factory Expr.fromJson(Map<String, dynamic> json) {
    Expr child(String key) => Expr.fromJson(json[key] as Map<String, dynamic>);
    switch (json['type'] as String) {
      case 'const':
        return ConstExpr((json['value'] as num).toDouble());
      case 'var':
        return const VarExpr();
      case 'add':
        return AddExpr(child('a'), child('b'));
      case 'sub':
        return SubExpr(child('a'), child('b'));
      case 'mul':
        return MulExpr(child('a'), child('b'));
      case 'div':
        return DivExpr(child('a'), child('b'));
      case 'pow':
        return PowExpr(child('a'), child('b'));
      case 'neg':
        return NegExpr(child('a'));
      case 'sin':
        return SinExpr(child('a'));
      case 'cos':
        return CosExpr(child('a'));
      case 'tan':
        return TanExpr(child('a'));
      case 'asin':
        return AsinExpr(child('a'));
      case 'acos':
        return AcosExpr(child('a'));
      case 'atan':
        return AtanExpr(child('a'));
      case 'ln':
        return LnExpr(child('a'));
      case 'log10':
        return Log10Expr(child('a'));
      case 'exp':
        return ExpExpr(child('a'));
      case 'sqrt':
        return SqrtExpr(child('a'));
      default:
        throw FormatException('Unknown Expr type: ${json['type']}');
    }
  }

  /// Structural equality, derived from [toJson] (which every node already
  /// needs for persistence) rather than hand-written per node.
  @override
  bool operator ==(Object other) =>
      other is Expr && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => toDisplayString();
}

/// Wraps [child] in parentheses if its precedence is below [minPrecedence]
/// — the shared parenthesization rule every binary/unary node uses.
String _fmt(Expr child, int minPrecedence) {
  final s = child.toDisplayString();
  return child.precedence < minPrecedence ? '($s)' : s;
}

String _formatNumber(double v) {
  if (v.isFinite && v == v.roundToDouble() && v.abs() < 1e15) {
    return v.toInt().toString();
  }
  var s = v.toStringAsPrecision(6);
  if (s.contains('.') && !s.contains('e')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

class ConstExpr extends Expr {
  const ConstExpr(this.value);

  final double value;

  @override
  double eval(double x) => value;

  @override
  Expr differentiate() => const ConstExpr(0);

  @override
  Expr simplify() => this;

  // Negative constants parenthesize like NegExpr (e.g. as a Pow base,
  // (-2)^3 vs -2^3 are different values) — everything else is atomic.
  @override
  int get precedence => value < 0 ? 3 : 5;

  @override
  String toDisplayString() => _formatNumber(value);

  @override
  Map<String, dynamic> toJson() => {'type': 'const', 'value': value};
}

class VarExpr extends Expr {
  const VarExpr();

  @override
  double eval(double x) => x;

  @override
  Expr differentiate() => const ConstExpr(1);

  @override
  Expr simplify() => this;

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'x';

  @override
  Map<String, dynamic> toJson() => {'type': 'var'};
}

class AddExpr extends Expr {
  const AddExpr(this.a, this.b);

  final Expr a;
  final Expr b;

  @override
  double eval(double x) => a.eval(x) + b.eval(x);

  @override
  Expr differentiate() => AddExpr(a.differentiate(), b.differentiate());

  @override
  Expr simplify() {
    final sa = a.simplify();
    final sb = b.simplify();
    if (sa is ConstExpr && sb is ConstExpr) {
      return ConstExpr(sa.value + sb.value);
    }
    if (sb is ConstExpr && sb.value == 0) return sa;
    if (sa is ConstExpr && sa.value == 0) return sb;
    if (sb is NegExpr) return SubExpr(sa, sb.a).simplify();
    if (sb is ConstExpr && sb.value < 0) {
      return SubExpr(sa, ConstExpr(-sb.value)).simplify();
    }
    return AddExpr(sa, sb);
  }

  @override
  int get precedence => 1;

  @override
  String toDisplayString() => '${_fmt(a, 1)} + ${_fmt(b, 1)}';

  @override
  Map<String, dynamic> toJson() => {
    'type': 'add',
    'a': a.toJson(),
    'b': b.toJson(),
  };
}

class SubExpr extends Expr {
  const SubExpr(this.a, this.b);

  final Expr a;
  final Expr b;

  @override
  double eval(double x) => a.eval(x) - b.eval(x);

  @override
  Expr differentiate() => SubExpr(a.differentiate(), b.differentiate());

  @override
  Expr simplify() {
    final sa = a.simplify();
    final sb = b.simplify();
    if (sa is ConstExpr && sb is ConstExpr) {
      return ConstExpr(sa.value - sb.value);
    }
    if (sb is ConstExpr && sb.value == 0) return sa;
    if (sa is ConstExpr && sa.value == 0) return NegExpr(sb).simplify();
    if (sa == sb) return const ConstExpr(0);
    return SubExpr(sa, sb);
  }

  @override
  int get precedence => 1;

  @override
  String toDisplayString() => '${_fmt(a, 1)} - ${_fmt(b, 2)}';

  @override
  Map<String, dynamic> toJson() => {
    'type': 'sub',
    'a': a.toJson(),
    'b': b.toJson(),
  };
}

class MulExpr extends Expr {
  const MulExpr(this.a, this.b);

  final Expr a;
  final Expr b;

  @override
  double eval(double x) => a.eval(x) * b.eval(x);

  @override
  Expr differentiate() =>
      AddExpr(MulExpr(a.differentiate(), b), MulExpr(a, b.differentiate()));

  @override
  Expr simplify() {
    final sa = a.simplify();
    final sb = b.simplify();
    if (sa is ConstExpr && sa.value == 0) return const ConstExpr(0);
    if (sb is ConstExpr && sb.value == 0) return const ConstExpr(0);
    if (sa is ConstExpr && sb is ConstExpr) {
      return ConstExpr(sa.value * sb.value);
    }
    if (sa is ConstExpr && sa.value == 1) return sb;
    if (sb is ConstExpr && sb.value == 1) return sa;
    return MulExpr(sa, sb);
  }

  @override
  int get precedence => 2;

  @override
  String toDisplayString() => '${_fmt(a, 2)} * ${_fmt(b, 2)}';

  @override
  Map<String, dynamic> toJson() => {
    'type': 'mul',
    'a': a.toJson(),
    'b': b.toJson(),
  };
}

class DivExpr extends Expr {
  const DivExpr(this.a, this.b);

  final Expr a;
  final Expr b;

  @override
  double eval(double x) => a.eval(x) / b.eval(x);

  @override
  Expr differentiate() => DivExpr(
    SubExpr(MulExpr(a.differentiate(), b), MulExpr(a, b.differentiate())),
    PowExpr(b, const ConstExpr(2)),
  );

  @override
  Expr simplify() {
    final sa = a.simplify();
    final sb = b.simplify();
    if (sb is ConstExpr && sb.value == 1) return sa;
    if (sa is ConstExpr && sa.value == 0) return const ConstExpr(0);
    if (sa is ConstExpr && sb is ConstExpr && sb.value != 0) {
      return ConstExpr(sa.value / sb.value);
    }
    // u^v / u -> u^(v-1): keeps power-rule derivatives (e.g. x^2 * 2/x)
    // reducing to the elementary form (2*x) instead of staying a fraction.
    if (sa is PowExpr && sa.a == sb) {
      return PowExpr(sa.a, SubExpr(sa.b, const ConstExpr(1))).simplify();
    }
    return DivExpr(sa, sb);
  }

  @override
  int get precedence => 2;

  @override
  String toDisplayString() => '${_fmt(a, 2)} / ${_fmt(b, 3)}';

  @override
  Map<String, dynamic> toJson() => {
    'type': 'div',
    'a': a.toJson(),
    'b': b.toJson(),
  };
}

class PowExpr extends Expr {
  const PowExpr(this.a, this.b);

  /// Base.
  final Expr a;

  /// Exponent.
  final Expr b;

  @override
  double eval(double x) => math.pow(a.eval(x), b.eval(x)).toDouble();

  // Generalized log-differentiation identity, so one rule covers a
  // constant exponent (x^2), a constant base (2^x), and both varying
  // (f(x)^g(x)): d/dx[u^v] = u^v * (v'*ln(u) + v*u'/u).
  //
  // Written here as u^v*v'*ln(u) + v*u' * (u^v/u) rather than the more
  // "obvious" u^v * (...) grouping, so the u^v/u sub-term actually appears
  // in the tree for DivExpr.simplify()'s power-rule rewrite to catch.
  @override
  Expr differentiate() {
    final da = a.differentiate();
    final db = b.differentiate();
    return AddExpr(
      MulExpr(MulExpr(PowExpr(a, b), db), LnExpr(a)),
      MulExpr(MulExpr(b, da), DivExpr(PowExpr(a, b), a)),
    );
  }

  @override
  Expr simplify() {
    final sa = a.simplify();
    final sb = b.simplify();
    if (sb is ConstExpr && sb.value == 1) return sa;
    if (sb is ConstExpr && sb.value == 0) return const ConstExpr(1);
    if (sa is ConstExpr && sa.value == 1) return const ConstExpr(1);
    if (sa is ConstExpr && sb is ConstExpr) {
      return ConstExpr(math.pow(sa.value, sb.value).toDouble());
    }
    return PowExpr(sa, sb);
  }

  @override
  int get precedence => 4;

  @override
  String toDisplayString() => '${_fmt(a, 5)}^${_fmt(b, 5)}';

  @override
  Map<String, dynamic> toJson() => {
    'type': 'pow',
    'a': a.toJson(),
    'b': b.toJson(),
  };
}

class NegExpr extends Expr {
  const NegExpr(this.a);

  final Expr a;

  @override
  double eval(double x) => -a.eval(x);

  @override
  Expr differentiate() => NegExpr(a.differentiate());

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr) return ConstExpr(-sa.value);
    if (sa is NegExpr) return sa.a;
    return NegExpr(sa);
  }

  @override
  int get precedence => 3;

  @override
  String toDisplayString() => '-${_fmt(a, 4)}';

  @override
  Map<String, dynamic> toJson() => {'type': 'neg', 'a': a.toJson()};
}

class SinExpr extends Expr {
  const SinExpr(this.a);

  final Expr a;

  @override
  double eval(double x) => math.sin(a.eval(x));

  @override
  Expr differentiate() => MulExpr(CosExpr(a), a.differentiate());

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr) return ConstExpr(math.sin(sa.value));
    return SinExpr(sa);
  }

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'sin(${a.toDisplayString()})';

  @override
  Map<String, dynamic> toJson() => {'type': 'sin', 'a': a.toJson()};
}

class CosExpr extends Expr {
  const CosExpr(this.a);

  final Expr a;

  @override
  double eval(double x) => math.cos(a.eval(x));

  @override
  Expr differentiate() => NegExpr(MulExpr(SinExpr(a), a.differentiate()));

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr) return ConstExpr(math.cos(sa.value));
    return CosExpr(sa);
  }

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'cos(${a.toDisplayString()})';

  @override
  Map<String, dynamic> toJson() => {'type': 'cos', 'a': a.toJson()};
}

class TanExpr extends Expr {
  const TanExpr(this.a);

  final Expr a;

  @override
  double eval(double x) => math.tan(a.eval(x));

  @override
  Expr differentiate() =>
      DivExpr(a.differentiate(), PowExpr(CosExpr(a), const ConstExpr(2)));

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr) return ConstExpr(math.tan(sa.value));
    return TanExpr(sa);
  }

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'tan(${a.toDisplayString()})';

  @override
  Map<String, dynamic> toJson() => {'type': 'tan', 'a': a.toJson()};
}

class AsinExpr extends Expr {
  const AsinExpr(this.a);

  final Expr a;

  @override
  double eval(double x) => math.asin(a.eval(x));

  @override
  Expr differentiate() => DivExpr(
    a.differentiate(),
    SqrtExpr(SubExpr(const ConstExpr(1), PowExpr(a, const ConstExpr(2)))),
  );

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr) return ConstExpr(math.asin(sa.value));
    return AsinExpr(sa);
  }

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'asin(${a.toDisplayString()})';

  @override
  Map<String, dynamic> toJson() => {'type': 'asin', 'a': a.toJson()};
}

class AcosExpr extends Expr {
  const AcosExpr(this.a);

  final Expr a;

  @override
  double eval(double x) => math.acos(a.eval(x));

  @override
  Expr differentiate() => NegExpr(
    DivExpr(
      a.differentiate(),
      SqrtExpr(SubExpr(const ConstExpr(1), PowExpr(a, const ConstExpr(2)))),
    ),
  );

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr) return ConstExpr(math.acos(sa.value));
    return AcosExpr(sa);
  }

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'acos(${a.toDisplayString()})';

  @override
  Map<String, dynamic> toJson() => {'type': 'acos', 'a': a.toJson()};
}

class AtanExpr extends Expr {
  const AtanExpr(this.a);

  final Expr a;

  @override
  double eval(double x) => math.atan(a.eval(x));

  @override
  Expr differentiate() => DivExpr(
    a.differentiate(),
    AddExpr(const ConstExpr(1), PowExpr(a, const ConstExpr(2))),
  );

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr) return ConstExpr(math.atan(sa.value));
    return AtanExpr(sa);
  }

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'atan(${a.toDisplayString()})';

  @override
  Map<String, dynamic> toJson() => {'type': 'atan', 'a': a.toJson()};
}

class LnExpr extends Expr {
  const LnExpr(this.a);

  final Expr a;

  @override
  double eval(double x) => math.log(a.eval(x));

  @override
  Expr differentiate() => DivExpr(a.differentiate(), a);

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr) return ConstExpr(math.log(sa.value));
    return LnExpr(sa);
  }

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'ln(${a.toDisplayString()})';

  @override
  Map<String, dynamic> toJson() => {'type': 'ln', 'a': a.toJson()};
}

class Log10Expr extends Expr {
  const Log10Expr(this.a);

  final Expr a;

  @override
  double eval(double x) => math.log(a.eval(x)) / math.ln10;

  @override
  Expr differentiate() =>
      DivExpr(a.differentiate(), MulExpr(a, const ConstExpr(math.ln10)));

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr) return ConstExpr(math.log(sa.value) / math.ln10);
    return Log10Expr(sa);
  }

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'log(${a.toDisplayString()})';

  @override
  Map<String, dynamic> toJson() => {'type': 'log10', 'a': a.toJson()};
}

class ExpExpr extends Expr {
  const ExpExpr(this.a);

  final Expr a;

  @override
  double eval(double x) => math.exp(a.eval(x));

  @override
  Expr differentiate() => MulExpr(ExpExpr(a), a.differentiate());

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr) return ConstExpr(math.exp(sa.value));
    return ExpExpr(sa);
  }

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'exp(${a.toDisplayString()})';

  @override
  Map<String, dynamic> toJson() => {'type': 'exp', 'a': a.toJson()};
}

class SqrtExpr extends Expr {
  const SqrtExpr(this.a);

  final Expr a;

  @override
  double eval(double x) => math.sqrt(a.eval(x));

  @override
  Expr differentiate() =>
      DivExpr(a.differentiate(), MulExpr(const ConstExpr(2), SqrtExpr(a)));

  @override
  Expr simplify() {
    final sa = a.simplify();
    if (sa is ConstExpr && sa.value >= 0) return ConstExpr(math.sqrt(sa.value));
    return SqrtExpr(sa);
  }

  @override
  int get precedence => 5;

  @override
  String toDisplayString() => 'sqrt(${a.toDisplayString()})';

  @override
  Map<String, dynamic> toJson() => {'type': 'sqrt', 'a': a.toJson()};
}
