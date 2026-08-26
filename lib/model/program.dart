import 'package:meta/meta.dart';

import 'opcode.dart';

/// One line of a stored program: an [Opcode] plus an optional operand.
///
/// The operand means different things depending on [op]:
/// - `digit` — the digit 0-9 entered
/// - `store`/`recall` — the memory register 0-9
/// - `lbl`/`gto`/`gsb` — the label number 0-99
/// - everything else (including `rtn` and all comparison tests) — `null`
@immutable
class ProgramStep {
  const ProgramStep(this.op, {this.operand});

  final Opcode op;
  final int? operand;

  Map<String, dynamic> toJson() => {
    'op': op.name,
    if (operand != null) 'operand': operand,
  };

  factory ProgramStep.fromJson(Map<String, dynamic> json) => ProgramStep(
    Opcode.values.byName(json['op'] as String),
    operand: json['operand'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is ProgramStep && other.op == op && other.operand == operand;

  @override
  int get hashCode => Object.hash(op, operand);

  @override
  String toString() =>
      operand == null ? op.name : '${op.name}($operand)';
}

/// A named, ordered list of [ProgramStep]s — a saved keystroke program.
@immutable
class Program {
  const Program({required this.name, required this.steps});

  final String name;
  final List<ProgramStep> steps;

  Program copyWith({String? name, List<ProgramStep>? steps}) =>
      Program(name: name ?? this.name, steps: steps ?? this.steps);

  Map<String, dynamic> toJson() => {
    'name': name,
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  factory Program.fromJson(Map<String, dynamic> json) => Program(
    name: json['name'] as String,
    steps: (json['steps'] as List)
        .map((s) => ProgramStep.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}
