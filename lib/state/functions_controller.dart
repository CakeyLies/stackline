import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/expr.dart';
import '../model/opcode.dart';

/// A named symbolic function: `y = f(x)`.
class CalcFunction {
  const CalcFunction({required this.name, required this.body});

  final String name;
  final Expr body;

  CalcFunction copyWith({String? name, Expr? body}) =>
      CalcFunction(name: name ?? this.name, body: body ?? this.body);

  Map<String, dynamic> toJson() => {'name': name, 'body': body.toJson()};

  factory CalcFunction.fromJson(Map<String, dynamic> json) => CalcFunction(
    name: json['name'] as String,
    body: Expr.fromJson(json['body'] as Map<String, dynamic>),
  );
}

enum _PendingRegisterOp { store, recall }

/// Builds and stores symbolic functions using the same keypad as live
/// calculation (see `Keypad._onKey`'s symbolic-mode branch), but operating
/// on a parallel 4-level stack of [Expr] instead of `Decimal` — so
/// "2 ENTER 3 +" builds the expression `2 + 3` instead of computing `5`.
///
/// Number entry and stack-lift rules mirror `CalculatorEngine` (a proven
/// pattern, not reinvented), simplified: no scientific-notation entry for
/// symbolic constants, and `factorial`/`percent`/`percentChange` are
/// rejected with [error] rather than silently no-opping, since they have no
/// symbolic meaning.
class FunctionsController extends ChangeNotifier {
  FunctionsController({
    required SharedPreferences prefs,
    required VoidCallback onChanged,
    // ignore: prefer_initializing_formals
  }) : _prefs = prefs,
       // ignore: prefer_initializing_formals
       _onChanged = onChanged {
    _load();
    _resetStack();
  }

  static const _kFunctions = 'functions_json';

  final SharedPreferences _prefs;
  final VoidCallback _onChanged;

  List<CalcFunction> saved = [];
  CalcFunction? current;
  bool isEditing = false;
  String? error;

  late List<Expr> _stack; // index 0=X, 1=Y, 2=Z, 3=T
  final List<Expr> _memory = List<Expr>.filled(10, const ConstExpr(0));

  bool _entryActive = false;
  String _mantissa = '';
  bool _negative = false;
  bool _stackLiftEnabled = true;
  _PendingRegisterOp? _pendingRegister;

  Expr get x => _stack[0];
  Expr get y => _stack[1];
  Expr get z => _stack[2];
  Expr get t => _stack[3];

  bool get awaitingRegister => _pendingRegister != null;

  /// Commits any in-progress digit entry and returns the current X
  /// expression — used by "Differentiate"/"Graph" actions that need the
  /// up-to-date expression even if the user is mid-keystroke.
  Expr commitX() {
    _commitIfNeeded();
    _notifyOnly();
    return _stack[0];
  }

  String get xDisplay =>
      _entryActive ? _entryString() : _stack[0].toDisplayString();
  String get yDisplay => _stack[1].toDisplayString();
  String get zDisplay => _stack[2].toDisplayString();
  String get tDisplay => _stack[3].toDisplayString();

  void _resetStack() {
    _stack = List<Expr>.filled(4, const ConstExpr(0), growable: false);
    _entryActive = false;
    _mantissa = '';
    _negative = false;
    _stackLiftEnabled = true;
    _pendingRegister = null;
    error = null;
  }

  String _entryString() =>
      (_negative ? '-' : '') + (_mantissa.isEmpty ? '0' : _mantissa);

  void _beginEntry() {
    if (_entryActive) return;
    if (_stackLiftEnabled) _lift();
    _entryActive = true;
    _mantissa = '';
    _negative = false;
  }

  void _lift() {
    _stack[3] = _stack[2];
    _stack[2] = _stack[1];
    _stack[1] = _stack[0];
  }

  void _commitIfNeeded() {
    if (_entryActive) {
      var s = _entryString();
      if (s.isEmpty || s == '-' || s == '.') s = '0';
      _stack[0] = ConstExpr(double.tryParse(s) ?? 0);
      _entryActive = false;
      _mantissa = '';
      _negative = false;
    }
  }

  Expr _commitX() {
    _commitIfNeeded();
    return _stack[0];
  }

  void _load() {
    final raw = _prefs.getString(_kFunctions);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      saved = list
          .map((e) => CalcFunction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      saved = [];
    }
  }

  void _persistAndNotify() {
    _prefs.setString(
      _kFunctions,
      jsonEncode(saved.map((f) => f.toJson()).toList()),
    );
    _notifyOnly();
  }

  void _notifyOnly() {
    notifyListeners();
    _onChanged();
  }

  void newFunction(String name) {
    current = CalcFunction(name: name, body: const VarExpr());
    isEditing = false;
    _resetStack();
    _notifyOnly();
  }

  void openFunction(CalcFunction f) {
    current = f;
    isEditing = false;
    _resetStack();
    _stack[0] = f.body;
    _notifyOnly();
  }

  void closeFunction() {
    current = null;
    isEditing = false;
    _notifyOnly();
  }

  void startEditing() {
    if (current == null) return;
    isEditing = true;
    _notifyOnly();
  }

  void stopEditing() {
    isEditing = false;
    _pendingRegister = null;
    _notifyOnly();
  }

  /// Pushes the free variable `x` — the one affordance with no live-keypad
  /// equivalent, offered as its own chip in the function editor's toolbar.
  void pushVariable() {
    if (!isEditing) return;
    _pushConstant(const VarExpr());
    _notifyOnly();
  }

  void _pushConstant(Expr value) {
    _commitIfNeeded();
    if (_stackLiftEnabled) _lift();
    _stack[0] = value;
    _stackLiftEnabled = true;
  }

  void _binary(Expr Function(Expr a, Expr b) f) {
    final xVal = _commitX();
    final yVal = _stack[1];
    _stack[0] = f(yVal, xVal);
    _stack[1] = _stack[2];
    _stack[2] = _stack[3];
    _stackLiftEnabled = true;
  }

  void _unary(Expr Function(Expr a) f) {
    final xVal = _commitX();
    _stack[0] = f(xVal);
    _stackLiftEnabled = true;
  }

  void handleKey(Opcode op, {int? digitValue}) {
    if (!isEditing) return;
    error = null;

    if (_pendingRegister != null) {
      if (op == Opcode.digit && digitValue != null) {
        if (_pendingRegister == _PendingRegisterOp.store) {
          _memory[digitValue] = _commitX();
        } else {
          _commitIfNeeded();
          _lift();
          _stack[0] = _memory[digitValue];
          _stackLiftEnabled = true;
        }
      }
      _pendingRegister = null;
      _notifyOnly();
      return;
    }

    switch (op) {
      case Opcode.digit:
        _beginEntry();
        _mantissa += digitValue.toString();
      case Opcode.decimalPoint:
        _beginEntry();
        if (!_mantissa.contains('.')) {
          _mantissa = _mantissa.isEmpty ? '0.' : '$_mantissa.';
        }
      case Opcode.changeSign:
        _beginEntry();
        _negative = !_negative;
      case Opcode.backspace:
        if (_entryActive && _mantissa.isNotEmpty) {
          _mantissa = _mantissa.substring(0, _mantissa.length - 1);
        } else if (_entryActive) {
          _entryActive = false;
          _negative = false;
        } else {
          _stack[0] = const ConstExpr(0);
        }
      case Opcode.enterExponent:
        break; // no scientific-notation entry for symbolic constants
      case Opcode.enter:
        _commitIfNeeded();
        _lift();
        _stackLiftEnabled = false;
      case Opcode.swapXY:
        _commitIfNeeded();
        final tmp = _stack[0];
        _stack[0] = _stack[1];
        _stack[1] = tmp;
        _stackLiftEnabled = true;
      case Opcode.rollDown:
        _commitIfNeeded();
        final xVal = _stack[0];
        _stack[0] = _stack[1];
        _stack[1] = _stack[2];
        _stack[2] = _stack[3];
        _stack[3] = xVal;
        _stackLiftEnabled = true;
      case Opcode.rollUp:
        _commitIfNeeded();
        final tVal = _stack[3];
        _stack[3] = _stack[2];
        _stack[2] = _stack[1];
        _stack[1] = _stack[0];
        _stack[0] = tVal;
        _stackLiftEnabled = true;
      case Opcode.lastX:
        break; // no "last op" concept in symbolic mode
      case Opcode.clearX:
        _entryActive = false;
        _mantissa = '';
        _negative = false;
        _stack[0] = const ConstExpr(0);
        _stackLiftEnabled = false;
      case Opcode.clearAll:
        _resetStack();
      case Opcode.store:
        _pendingRegister = _PendingRegisterOp.store;
      case Opcode.recall:
        _pendingRegister = _PendingRegisterOp.recall;
      case Opcode.pi:
        _pushConstant(const ConstExpr(math.pi));
      case Opcode.eConst:
        _pushConstant(const ConstExpr(math.e));
      case Opcode.add:
        _binary(AddExpr.new);
      case Opcode.subtract:
        _binary(SubExpr.new);
      case Opcode.multiply:
        _binary(MulExpr.new);
      case Opcode.divide:
        _binary(DivExpr.new);
      case Opcode.power:
        _binary(PowExpr.new);
      case Opcode.root:
        _binary((a, b) => PowExpr(a, DivExpr(const ConstExpr(1), b)));
      case Opcode.reciprocal:
        _unary((a) => DivExpr(const ConstExpr(1), a));
      case Opcode.sqrt:
        _unary(SqrtExpr.new);
      case Opcode.square:
        _unary((a) => PowExpr(a, const ConstExpr(2)));
      case Opcode.log10:
        _unary(Log10Expr.new);
      case Opcode.ln:
        _unary(LnExpr.new);
      case Opcode.tenToX:
        _unary((a) => PowExpr(const ConstExpr(10), a));
      case Opcode.eToX:
        _unary(ExpExpr.new);
      case Opcode.sin:
        _unary(SinExpr.new);
      case Opcode.cos:
        _unary(CosExpr.new);
      case Opcode.tan:
        _unary(TanExpr.new);
      case Opcode.asin:
        _unary(AsinExpr.new);
      case Opcode.acos:
        _unary(AcosExpr.new);
      case Opcode.atan:
        _unary(AtanExpr.new);
      case Opcode.percent:
      case Opcode.percentChange:
      case Opcode.factorial:
        error = '${opcodeLabel(op)} has no symbolic meaning';
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
        break; // program-only; never reach here from the function editor
    }
    _notifyOnly();
  }

  void saveCurrent() {
    final f = current;
    if (f == null) return;
    _commitIfNeeded();
    final updated = f.copyWith(body: _stack[0]);
    final index = saved.indexWhere((s) => s.name == f.name);
    if (index >= 0) {
      saved = List.of(saved)..[index] = updated;
    } else {
      saved = [...saved, updated];
    }
    current = updated;
    _persistAndNotify();
  }

  void deleteFunction(CalcFunction f) {
    saved = saved.where((s) => s.name != f.name).toList();
    if (current?.name == f.name) {
      current = null;
    }
    _persistAndNotify();
  }

  void renameFunction(CalcFunction f, String newName) {
    final index = saved.indexWhere((s) => s.name == f.name);
    if (index < 0) return;
    final renamed = f.copyWith(name: newName);
    saved = List.of(saved)..[index] = renamed;
    if (current?.name == f.name) current = renamed;
    _persistAndNotify();
  }
}
