import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';
import '../engine/program_engine.dart';
import '../model/opcode.dart';
import '../model/program.dart';

enum _PendingRegisterOp { store, recall }

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

  _PendingRegisterOp? _pendingRegister;

  /// True right after STO/RCL is tapped while recording, awaiting the
  /// register digit — mirrors the live calculator's STO/RCL two-tap flow,
  /// kept fully separate from [CalculatorController.pending] so recording
  /// can never leak a stale "STO" indicator into live calculator use.
  bool get awaitingRegister => _pendingRegister != null;

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
    _pendingRegister = null;
    _notifyOnly();
  }

  void openProgram(Program p) {
    current = p;
    draftSteps = List.of(p.steps);
    isRecording = false;
    _pendingRegister = null;
    _notifyOnly();
  }

  void closeProgram() {
    current = null;
    draftSteps = [];
    isRecording = false;
    _pendingRegister = null;
    _notifyOnly();
  }

  void startRecording() {
    if (current == null) return;
    isRecording = true;
    _notifyOnly();
  }

  void stopRecording() {
    isRecording = false;
    _pendingRegister = null;
    _notifyOnly();
  }

  /// Appends the tapped key as a program step. STO/RCL are two taps on the
  /// real keypad (press STO, then a digit for the register) — composed here
  /// into one [ProgramStep] rather than recording a meaningless bare "STO"
  /// line followed by a "digit" line.
  void recordKey(Opcode op, {int? digitValue}) {
    if (!isRecording) return;

    if (_pendingRegister != null) {
      if (op == Opcode.digit && digitValue != null) {
        final regOp = _pendingRegister == _PendingRegisterOp.store
            ? Opcode.store
            : Opcode.recall;
        draftSteps = [...draftSteps, ProgramStep(regOp, operand: digitValue)];
      }
      _pendingRegister = null;
      _notifyOnly();
      return;
    }

    if (op == Opcode.store) {
      _pendingRegister = _PendingRegisterOp.store;
      _notifyOnly();
      return;
    }
    if (op == Opcode.recall) {
      _pendingRegister = _PendingRegisterOp.recall;
      _notifyOnly();
      return;
    }

    draftSteps = [...draftSteps, ProgramStep(op, operand: digitValue)];
    _notifyOnly();
  }

  void deleteStepAt(int index) {
    draftSteps = List.of(draftSteps)..removeAt(index);
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
