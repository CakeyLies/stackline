import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/display.dart';
import '../engine/engine.dart';
import '../model/display_style.dart';
import '../model/theme.dart';
import 'functions_controller.dart';
import 'programs_controller.dart';

enum PendingOp { store, recall }

class CalculatorController extends ChangeNotifier {
  CalculatorController(this._prefs) {
    programs = ProgramsController(
      engine: engine,
      prefs: _prefs,
      onChanged: _notify,
    );
    functions = FunctionsController(prefs: _prefs, onChanged: _notify);
    _loadPrefs();
  }

  static const _kTheme = 'theme';
  static const _kAngle = 'angle';
  static const _kDisplayMode = 'display_mode';
  static const _kDigits = 'digits';
  static const _kDisplayStyle = 'display_style';

  final SharedPreferences _prefs;
  final CalculatorEngine engine = CalculatorEngine();
  late final ProgramsController programs;
  late final FunctionsController functions;

  CalcTheme theme = CalcTheme.presets.first;
  DisplayStyle displayStyle = DisplayStyle.classic;
  PendingOp? pending;
  bool _shift = false;

  bool get shift => _shift;
  bool get isRecordingProgram => programs.isRecording;
  bool get isSymbolicEditing => functions.isEditing;

  void _loadPrefs() {
    theme = CalcTheme.byName(_prefs.getString(_kTheme));
    final angleIndex = _prefs.getInt(_kAngle);
    if (angleIndex != null && angleIndex < AngleMode.values.length) {
      engine.angleMode = AngleMode.values[angleIndex];
    }
    final modeIndex = _prefs.getInt(_kDisplayMode);
    if (modeIndex != null && modeIndex < DisplayMode.values.length) {
      engine.displayMode = DisplayMode.values[modeIndex];
    }
    final digits = _prefs.getInt(_kDigits);
    if (digits != null) {
      engine.displayDigits = digits.clamp(0, 9);
    }
    final styleIndex = _prefs.getInt(_kDisplayStyle);
    if (styleIndex != null && styleIndex < DisplayStyle.values.length) {
      displayStyle = DisplayStyle.values[styleIndex];
    }
  }

  void _persist() {
    _prefs.setString(_kTheme, theme.name);
    _prefs.setInt(_kAngle, engine.angleMode.index);
    _prefs.setInt(_kDisplayMode, engine.displayMode.index);
    _prefs.setInt(_kDigits, engine.displayDigits);
    _prefs.setInt(_kDisplayStyle, displayStyle.index);
  }

  void _notify() {
    _persist();
    notifyListeners();
  }

  void _cancelPending() => pending = null;

  // ---- number entry ----
  void digit(int d) {
    if (pending != null) {
      final p = pending!;
      pending = null;
      if (d >= 0 && d <= 9) {
        if (p == PendingOp.store) {
          engine.store(d);
        } else {
          engine.recall(d);
        }
        _notify();
      }
      return;
    }
    engine.digit(d);
    _notify();
  }

  void decimalPoint() {
    _cancelPending();
    engine.decimalPoint();
    _notify();
  }

  void enterExponent() {
    _cancelPending();
    engine.enterExponent();
    _notify();
  }

  void changeSign() {
    _cancelPending();
    engine.changeSign();
    _notify();
  }

  void backspace() {
    _cancelPending();
    engine.backspace();
    _notify();
  }

  // ---- stack ----
  void enter() {
    _cancelPending();
    engine.enter();
    _notify();
  }

  void swapXY() {
    _cancelPending();
    engine.swapXY();
    _notify();
  }

  void rollDown() {
    _cancelPending();
    engine.rollDown();
    _notify();
  }

  void rollUp() {
    _cancelPending();
    engine.rollUp();
    _notify();
  }

  void lastXRecall() {
    _cancelPending();
    engine.lastXRecall();
    _notify();
  }

  void clearX() {
    _cancelPending();
    engine.clearX();
    _notify();
  }

  void clearAll() {
    _cancelPending();
    engine.clearAll();
    _notify();
  }

  // ---- memory ----
  void pressStore() {
    pending = PendingOp.store;
    _notify();
  }

  void pressRecall() {
    pending = PendingOp.recall;
    _notify();
  }

  void pressShift() {
    _cancelPending();
    _shift = !_shift;
    _notify();
  }

  void consumeShift() {
    _shift = false;
  }

  // ---- constants ----
  void pushPi() {
    _cancelPending();
    engine.pushPi();
    _notify();
  }

  void pushE() {
    _cancelPending();
    engine.pushE();
    _notify();
  }

  // ---- arithmetic ----
  void add() => _run(engine.add);
  void subtract() => _run(engine.subtract);
  void multiply() => _run(engine.multiply);
  void divide() => _run(engine.divide);
  void power() => _run(engine.power);
  void root() => _run(engine.root);
  void percent() => _run(engine.percent);
  void percentChange() => _run(engine.percentChange);

  // ---- unary ----
  void reciprocal() => _run(engine.reciprocal);
  void sqrt() => _run(engine.sqrt);
  void square() => _run(engine.square);
  void log10() => _run(engine.log10);
  void ln() => _run(engine.ln);
  void tenToX() => _run(engine.tenToX);
  void eToX() => _run(engine.eToX);
  void sin() => _run(engine.sin);
  void cos() => _run(engine.cos);
  void tan() => _run(engine.tan);
  void asin() => _run(engine.asin);
  void acos() => _run(engine.acos);
  void atan() => _run(engine.atan);
  void factorial() => _run(engine.factorial);

  void _run(void Function() op) {
    _cancelPending();
    op();
    _notify();
  }

  // ---- modes ----
  void cycleAngleMode() {
    engine.angleMode = AngleMode
        .values[(engine.angleMode.index + 1) % AngleMode.values.length];
    _notify();
  }

  void cycleDisplayMode() {
    engine.displayMode = DisplayMode
        .values[(engine.displayMode.index + 1) % DisplayMode.values.length];
    _notify();
  }

  void cycleDisplayDigits() {
    engine.displayDigits = (engine.displayDigits + 1) % 10;
    _notify();
  }

  void setTheme(CalcTheme value) {
    theme = value;
    _notify();
  }

  void setDisplayStyle(DisplayStyle value) {
    displayStyle = value;
    _notify();
  }

  // ---- display ----
  String get xText {
    final err = engine.errorMessage;
    if (err != null) return err;
    if (engine.entryActive) return engine.entryText;
    return formatDecimal(engine.x, engine.displayMode, engine.displayDigits);
  }

  String get yText =>
      formatDecimal(engine.y, engine.displayMode, engine.displayDigits);
  String get zText =>
      formatDecimal(engine.z, engine.displayMode, engine.displayDigits);
  String get tText =>
      formatDecimal(engine.t, engine.displayMode, engine.displayDigits);
  String get lastXText =>
      formatDecimal(engine.lastX, engine.displayMode, engine.displayDigits);

  String get angleLabel {
    switch (engine.angleMode) {
      case AngleMode.deg:
        return 'DEG';
      case AngleMode.rad:
        return 'RAD';
      case AngleMode.grad:
        return 'GRAD';
    }
  }

  String get displayModeLabel {
    switch (engine.displayMode) {
      case DisplayMode.fix:
        return 'FIX';
      case DisplayMode.sci:
        return 'SCI';
      case DisplayMode.eng:
        return 'ENG';
    }
  }

  String get displayLabel => '$displayModeLabel ${engine.displayDigits}';

  String get pendingLabel {
    switch (pending) {
      case PendingOp.store:
        return 'STO';
      case PendingOp.recall:
        return 'RCL';
      case null:
        return '';
    }
  }
}
