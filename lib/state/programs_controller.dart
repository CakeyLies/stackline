import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';
import '../engine/program_engine.dart';
import '../model/opcode.dart';
import '../model/program.dart';

enum _PendingKind { store, recall, lbl, gto, gsb }

/// Keystroke-program recording, storage, and execution.
///
/// A sibling to [CalculatorController], not bolted onto it: full program
/// CRUD plus an execution engine is a different order of magnitude than the
/// small bools/enums (`shift`, `pending`) already living on the main
/// controller. Constructed with an [onChanged] callback that bridges into
/// the main controller's own `notifyListeners()`, so the rest of the app
/// keeps working through its single existing `ListenableBuilder`.
class ProgramsController extends ChangeNotifier {
  ProgramsController({
    required this.engine,
    required SharedPreferences prefs,
    required VoidCallback onChanged,
    // ignore: prefer_initializing_formals
  }) : _prefs = prefs,
       // ignore: prefer_initializing_formals
       _onChanged = onChanged {
    _load();
  }

  static const _kPrograms = 'programs_json';

  final CalculatorEngine engine;
  final SharedPreferences _prefs;
  final VoidCallback _onChanged;

  List<Program> saved = [];
  Program? current;
  List<ProgramStep> draftSteps = [];
  bool isRecording = false;
  String? lastRunError;

  /// The step new keys are inserted after (null = insert at the end). Set by
  /// tapping a step in the editor's list, mirroring a real HP-41's
  /// current-line pointer.
  int? selectedIndex;

  _PendingKind? _pendingKind;
  String _pendingDigits = '';

  /// A short prompt for the editor to show while awaiting STO/RCL's
  /// register digit or LBL/GTO/GSB's 2-digit label — e.g. "GTO _5",
  /// completed digit-by-digit. Kept fully separate from
  /// [CalculatorController.pending] so recording can never leak a stale
  /// STO/RCL indicator into live calculator use.
  String? get pendingPrompt => switch (_pendingKind) {
    _PendingKind.store => 'STO _',
    _PendingKind.recall => 'RCL _',
    _PendingKind.lbl => 'LBL ${_pendingDigits.padRight(2, '_')}',
    _PendingKind.gto => 'GTO ${_pendingDigits.padRight(2, '_')}',
    _PendingKind.gsb => 'GSB ${_pendingDigits.padRight(2, '_')}',
    null => null,
  };

  void _load() {
    final raw = _prefs.getString(_kPrograms);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      saved = list
          .map((e) => Program.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      saved = [];
    }
  }

  void _persistAndNotify() {
    _prefs.setString(
      _kPrograms,
      jsonEncode(saved.map((p) => p.toJson()).toList()),
    );
    _notifyOnly();
  }

  void _notifyOnly() {
    notifyListeners();
    _onChanged();
  }

  void newProgram(String name) {
    current = Program(name: name, steps: const []);
    draftSteps = [];
    isRecording = false;
    selectedIndex = null;
    _cancelPending();
    _notifyOnly();
  }

  void openProgram(Program p) {
    current = p;
    draftSteps = List.of(p.steps);
    isRecording = false;
    selectedIndex = null;
    _cancelPending();
    _notifyOnly();
  }

  void closeProgram() {
    current = null;
    draftSteps = [];
    isRecording = false;
    selectedIndex = null;
    _cancelPending();
    _notifyOnly();
  }

  void startRecording() {
    if (current == null) return;
    isRecording = true;
    _notifyOnly();
  }

  void stopRecording() {
    isRecording = false;
    _cancelPending();
    _notifyOnly();
  }

  void _cancelPending() {
    _pendingKind = null;
    _pendingDigits = '';
  }

  /// Selects the current-line pointer — new steps are inserted right after
  /// it instead of always appended at the end. Pass null to point past the
  /// end (append).
  void selectStep(int? index) {
    selectedIndex = index;
    _notifyOnly();
  }

  void _appendStep(ProgramStep step) {
    final insertAt =
        (selectedIndex == null || selectedIndex! >= draftSteps.length)
        ? draftSteps.length
        : selectedIndex! + 1;
    draftSteps = [
      ...draftSteps.sublist(0, insertAt),
      step,
      ...draftSteps.sublist(insertAt),
    ];
    selectedIndex = insertAt;
  }

  /// Appends the tapped key as a program step (inserted after
  /// [selectedIndex], see [_appendStep]).
  ///
  /// STO/RCL are two taps on the real keypad (press STO, then a digit for
  /// the register); LBL/GTO/GSB are a press plus exactly two digits (labels
  /// are always 00-99, matching the HP-41 convention) — both composed here
  /// into one [ProgramStep] rather than recording meaningless bare lines.
  /// Any non-digit key while an operand is pending cancels it rather than
  /// guessing what the user meant.
  void recordKey(Opcode op, {int? digitValue}) {
    if (!isRecording) return;

    if (_pendingKind != null) {
      if (op != Opcode.digit || digitValue == null) {
        _cancelPending();
        _notifyOnly();
        return;
      }
      switch (_pendingKind!) {
        case _PendingKind.store:
        case _PendingKind.recall:
          final regOp = _pendingKind == _PendingKind.store
              ? Opcode.store
              : Opcode.recall;
          _appendStep(ProgramStep(regOp, operand: digitValue));
          _cancelPending();
        case _PendingKind.lbl:
        case _PendingKind.gto:
        case _PendingKind.gsb:
          _pendingDigits += digitValue.toString();
          if (_pendingDigits.length >= 2) {
            final controlOp = switch (_pendingKind!) {
              _PendingKind.lbl => Opcode.lbl,
              _PendingKind.gto => Opcode.gto,
              _PendingKind.gsb => Opcode.gsb,
              _PendingKind.store ||
              _PendingKind.recall => throw StateError('unreachable'),
            };
            _appendStep(
              ProgramStep(controlOp, operand: int.parse(_pendingDigits)),
            );
            _cancelPending();
          }
      }
      _notifyOnly();
      return;
    }

    switch (op) {
      case Opcode.store:
        _pendingKind = _PendingKind.store;
      case Opcode.recall:
        _pendingKind = _PendingKind.recall;
      case Opcode.lbl:
        _pendingKind = _PendingKind.lbl;
      case Opcode.gto:
        _pendingKind = _PendingKind.gto;
      case Opcode.gsb:
        _pendingKind = _PendingKind.gsb;
      default:
        _appendStep(ProgramStep(op, operand: digitValue));
    }
    _notifyOnly();
  }

  void deleteStepAt(int index) {
    draftSteps = List.of(draftSteps)..removeAt(index);
    if (selectedIndex != null) {
      if (selectedIndex == index) {
        selectedIndex = index == 0 ? null : index - 1;
      } else if (selectedIndex! > index) {
        selectedIndex = selectedIndex! - 1;
      }
    }
    _notifyOnly();
  }

  void saveCurrent() {
    final program = current;
    if (program == null) return;
    final updated = program.copyWith(steps: draftSteps);
    final index = saved.indexWhere((p) => p.name == program.name);
    if (index >= 0) {
      saved = List.of(saved)..[index] = updated;
    } else {
      saved = [...saved, updated];
    }
    current = updated;
    _persistAndNotify();
  }

  void deleteProgram(Program p) {
    saved = saved.where((s) => s.name != p.name).toList();
    if (current?.name == p.name) {
      current = null;
      draftSteps = [];
    }
    _persistAndNotify();
  }

  void renameProgram(Program p, String newName) {
    final index = saved.indexWhere((s) => s.name == p.name);
    if (index < 0) return;
    final renamed = p.copyWith(name: newName);
    saved = List.of(saved)..[index] = renamed;
    if (current?.name == p.name) current = renamed;
    _persistAndNotify();
  }

  /// Runs [program] against the shared [CalculatorEngine]. Returns null on
  /// success, or a friendly error message (also left in [lastRunError]).
  String? run(Program program) {
    lastRunError = null;
    try {
      ProgramEngine(engine).run(program);
    } on CalcError catch (e) {
      lastRunError = e.message;
    }
    _notifyOnly();
    return lastRunError;
  }
}
