import 'dart:math' as math;

import 'package:decimal/decimal.dart';

enum AngleMode { deg, rad, grad }

enum DisplayMode { fix, sci, eng }

class CalcError implements Exception {
  final String message;
  const CalcError(this.message);

  @override
  String toString() => message;
}

class CalculatorEngine {
  CalculatorEngine();

  static const int _maxScale = 40;

  final List<Decimal> _stack = List<Decimal>.filled(4, Decimal.zero);
  Decimal _lastX = Decimal.zero;
  final List<Decimal> _memory = List<Decimal>.filled(10, Decimal.zero);

  AngleMode angleMode = AngleMode.deg;
  DisplayMode displayMode = DisplayMode.fix;
  int displayDigits = 4;

  bool _entryActive = false;
  String _mantissa = '';
  bool _negative = false;
  bool _inExponent = false;
  String _exponent = '';
  bool _expNegative = false;

  bool _stackLiftEnabled = true;

  String? error;

  Decimal get x => _stack[0];
  Decimal get y => _stack[1];
  Decimal get z => _stack[2];
  Decimal get t => _stack[3];
  Decimal get lastX => _lastX;
  bool get entryActive => _entryActive;
  String get entryText => _entryActive ? _entryString() : '';
  String? get errorMessage => error;

  String _entryString() {
    final m = _mantissa.isEmpty ? '0' : _mantissa;
    var s = (_negative ? '-' : '') + m;
    if (_inExponent || _exponent.isNotEmpty) {
      final e = _exponent.isEmpty ? '0' : _exponent;
      s += 'E${_expNegative ? '-' : ''}$e';
    }
    return s;
  }

  void _clearError() => error = null;

  void _beginEntry() {
    if (_entryActive) return;
    if (_stackLiftEnabled) _lift();
    _entryActive = true;
    _mantissa = '';
    _negative = false;
    _inExponent = false;
    _exponent = '';
    _expNegative = false;
  }

  void _lift() {
    _stack[3] = _stack[2];
    _stack[2] = _stack[1];
    _stack[1] = _stack[0];
  }

  Decimal _parseEntry() {
    var s = _entryString();
    if (s.isEmpty || s == '-' || s == '.') s = '0';
    return Decimal.tryParse(s) ?? Decimal.zero;
  }

  void _commitIfNeeded() {
    if (_entryActive) {
      _stack[0] = _parseEntry();
      _entryActive = false;
      _mantissa = '';
      _negative = false;
      _inExponent = false;
      _exponent = '';
      _expNegative = false;
    }
  }

  Decimal _commitX() {
    _commitIfNeeded();
    return _stack[0];
  }

  void _setError(String message) {
    error = message;
  }

  // ---- number entry ----
  void digit(int d) {
    _clearError();
    if (d < 0 || d > 9) return;
    _beginEntry();
    if (_inExponent) {
      _exponent += '$d';
    } else {
      _mantissa += '$d';
    }
  }

  void decimalPoint() {
    _clearError();
    _beginEntry();
    if (_inExponent) return;
    if (!_mantissa.contains('.')) {
      _mantissa = _mantissa.isEmpty ? '0.' : '$_mantissa.';
    }
  }

  void enterExponent() {
    _clearError();
    _beginEntry();
    _inExponent = true;
  }

  void changeSign() {
    _clearError();
    _beginEntry();
    if (_inExponent) {
      _expNegative = !_expNegative;
    } else {
      _negative = !_negative;
    }
  }

  void backspace() {
    _clearError();
    if (_entryActive) {
      if (_inExponent) {
        if (_exponent.isNotEmpty) {
          _exponent = _exponent.substring(0, _exponent.length - 1);
        } else {
          _inExponent = false;
        }
      } else if (_mantissa.isNotEmpty) {
        _mantissa = _mantissa.substring(0, _mantissa.length - 1);
      } else {
        _entryActive = false;
        _negative = false;
      }
    } else {
      clearX();
    }
  }

  // ---- stack control ----
  void enter() {
    _clearError();
    _commitIfNeeded();
    _stack[3] = _stack[2];
    _stack[2] = _stack[1];
    _stack[1] = _stack[0];
    _stackLiftEnabled = false;
  }

  void swapXY() {
    _clearError();
    final x = _commitX();
    final y = _stack[1];
    _lastX = x;
    _stack[0] = y;
    _stack[1] = x;
    _stackLiftEnabled = true;
  }

  void rollDown() {
    _clearError();
    _commitIfNeeded();
    final x = _stack[0];
    _stack[0] = _stack[1];
    _stack[1] = _stack[2];
    _stack[2] = _stack[3];
    _stack[3] = x;
    _stackLiftEnabled = true;
  }

  void rollUp() {
    _clearError();
    _commitIfNeeded();
    final t = _stack[3];
    _stack[3] = _stack[2];
    _stack[2] = _stack[1];
    _stack[1] = _stack[0];
    _stack[0] = t;
    _stackLiftEnabled = true;
  }

  void lastXRecall() {
    _clearError();
    _commitIfNeeded();
    _lift();
    _stack[0] = _lastX;
    _stackLiftEnabled = true;
  }

  void clearX() {
    _clearError();
    _entryActive = false;
    _mantissa = '';
    _negative = false;
    _inExponent = false;
    _exponent = '';
    _expNegative = false;
    _stack[0] = Decimal.zero;
    _stackLiftEnabled = false;
  }

  void clearAll() {
    clearX();
    for (var i = 0; i < 4; i++) {
      _stack[i] = Decimal.zero;
    }
    _lastX = Decimal.zero;
    for (var i = 0; i < _memory.length; i++) {
      _memory[i] = Decimal.zero;
    }
    _stackLiftEnabled = false;
  }

  // ---- memory ----
  void store(int n) {
    _clearError();
    _memory[n] = _commitX();
    _stackLiftEnabled = true;
  }

  void recall(int n) {
    _clearError();
    _commitIfNeeded();
    _lift();
    _stack[0] = _memory[n];
    _stackLiftEnabled = true;
  }

  // ---- constants ----
  void pushPi() {
    _pushConstant(_doubleToDecimal(math.pi));
  }

  void pushE() {
    _pushConstant(_doubleToDecimal(math.e));
  }

  void _pushConstant(Decimal value) {
    _clearError();
    _commitIfNeeded();
    if (_stackLiftEnabled) _lift();
    _stack[0] = value;
    _stackLiftEnabled = true;
  }

  // ---- arithmetic ----
  void add() => _binary((a, b) => a + b);

  void subtract() => _binary((a, b) => a - b);

  void multiply() => _binary((a, b) => a * b);

  void divide() => _binary((a, b) {
        if (b == Decimal.zero) throw const CalcError('Divide by 0');
        return _div(a, b);
      });

  void power() => _binary((a, b) => _pow(a, b));

  void root() => _binary((a, b) {
        if (b == Decimal.zero) throw const CalcError('Root of 0');
        return _pow(a, _div(Decimal.one, b));
      });

  void percent() {
    _clearError();
    final x = _commitX();
    final y = _stack[1];
    try {
      _lastX = x;
      _stack[0] = _div(y * x, Decimal.fromInt(100));
      _stackLiftEnabled = true;
    } on CalcError catch (e) {
      _setError(e.message);
    }
  }

  void percentChange() {
    _clearError();
    final x = _commitX();
    final y = _stack[1];
    try {
      if (y == Decimal.zero) throw const CalcError('Divide by 0');
      _lastX = x;
      _stack[0] = _div((x - y) * Decimal.fromInt(100), y);
      _stackLiftEnabled = true;
    } on CalcError catch (e) {
      _setError(e.message);
    }
  }

  void _binary(Decimal Function(Decimal a, Decimal b) f) {
    _clearError();
    final x = _commitX();
    final y = _stack[1];
    try {
      final r = f(y, x);
      _lastX = x;
      _stack[0] = r;
      _stack[1] = _stack[2];
      _stack[2] = _stack[3];
      _stackLiftEnabled = true;
    } on CalcError catch (e) {
      _setError(e.message);
    }
  }

  // ---- unary functions ----
  void reciprocal() => _unary((a) {
        if (a == Decimal.zero) throw const CalcError('Divide by 0');
        return _div(Decimal.one, a);
      });

  void sqrt() => _unary(_sqrtDecimal);

  void square() => _unary((a) => a * a);

  void log10() => _unary((a) {
        if (a <= Decimal.zero) throw const CalcError('Invalid data');
        return _doubleToDecimal(math.log(a.toDouble()) / math.ln10);
      });

  void ln() => _unary((a) {
        if (a <= Decimal.zero) throw const CalcError('Invalid data');
        return _doubleToDecimal(math.log(a.toDouble()));
      });

  void tenToX() => _unary((a) => _doubleToDecimal(math.pow(10, a.toDouble()).toDouble()));

  void eToX() => _unary((a) => _doubleToDecimal(math.exp(a.toDouble())));

  void sin() => _unary((a) => _doubleToDecimal(math.sin(_toRadians(a.toDouble()))));

  void cos() => _unary((a) => _doubleToDecimal(math.cos(_toRadians(a.toDouble()))));

  void tan() => _unary((a) => _doubleToDecimal(math.tan(_toRadians(a.toDouble()))));

  void asin() => _unary((a) {
        final d = a.toDouble();
        if (d < -1 || d > 1) throw const CalcError('Invalid data');
        return _doubleToDecimal(_fromRadians(math.asin(d)));
      });

  void acos() => _unary((a) {
        final d = a.toDouble();
        if (d < -1 || d > 1) throw const CalcError('Invalid data');
        return _doubleToDecimal(_fromRadians(math.acos(d)));
      });

  void atan() => _unary((a) => _doubleToDecimal(_fromRadians(math.atan(a.toDouble()))));

  void factorial() => _unary(_factorial);

  void _unary(Decimal Function(Decimal a) f) {
    _clearError();
    final x = _commitX();
    try {
      final r = f(x);
      _lastX = x;
      _stack[0] = r;
      _stackLiftEnabled = true;
    } on CalcError catch (e) {
      _setError(e.message);
    }
  }

  // ---- math helpers ----
  Decimal _div(Decimal a, Decimal b) =>
      (a / b).toDecimal(scaleOnInfinitePrecision: _maxScale);

  Decimal _pow(Decimal base, Decimal exponent) {
    final r = math.pow(base.toDouble(), exponent.toDouble());
    return _doubleToDecimal(r.toDouble());
  }

  Decimal _sqrtDecimal(Decimal a) {
    if (a.sign < 0) throw const CalcError('Invalid data');
    if (a == Decimal.zero) return Decimal.zero;
    var x = _doubleToDecimal(math.sqrt(a.toDouble()));
    for (var i = 0; i < 24; i++) {
      x = _div(_div(a, x) + x, Decimal.fromInt(2));
    }
    return x;
  }

  Decimal _factorial(Decimal a) {
    if (a.sign < 0 || !a.isInteger) throw const CalcError('Invalid data');
    final n = a.toBigInt();
    if (n > BigInt.from(1000)) throw const CalcError('Too large');
    var result = Decimal.one;
    for (var i = BigInt.one; i <= n; i += BigInt.one) {
      result = result * Decimal.fromBigInt(i);
    }
    return result;
  }

  Decimal _doubleToDecimal(double d) {
    if (d.isNaN) throw const CalcError('Invalid result');
    if (d.isInfinite) throw const CalcError('Out of range');
    return Decimal.parse(d.toStringAsPrecision(15));
  }

  double _toRadians(double d) {
    switch (angleMode) {
      case AngleMode.deg:
        return d * math.pi / 180;
      case AngleMode.grad:
        return d * math.pi / 200;
      case AngleMode.rad:
        return d;
    }
  }

  double _fromRadians(double r) {
    switch (angleMode) {
      case AngleMode.deg:
        return r * 180 / math.pi;
      case AngleMode.grad:
        return r * 200 / math.pi;
      case AngleMode.rad:
        return r;
    }
  }
}
