import 'package:flutter/material.dart';

import '../model/opcode.dart';
import '../model/program.dart';
import '../state/calculator_controller.dart';
import 'keypad.dart';

/// The saved-programs menu: create, open, rename, delete, run.
class ProgramsListScreen extends StatelessWidget {
  const ProgramsListScreen({super.key, required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        title: const Text('Programs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New program',
            onPressed: () => _createProgram(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller.programs,
        builder: (context, _) {
          final programs = controller.programs.saved;
          if (programs.isEmpty) {
            return Center(
              child: Text(
                'No programs yet.\nTap + to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.keyText.withValues(alpha: 0.6)),
              ),
            );
          }
          return ListView(
            children: [
              for (final program in programs)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _ProgramTile(controller: controller, program: program),
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createProgram(BuildContext context) async {
    final name = await _promptForName(context, title: 'New program');
    if (name == null || name.isEmpty) return;
    controller.programs.newProgram(name);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProgramEditorScreen(controller: controller),
      ),
    );
  }
}

Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Program name'),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _ProgramTile extends StatelessWidget {
  const _ProgramTile({required this.controller, required this.program});

  final CalculatorController controller;
  final Program program;

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    return Material(
      color: t.keyBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          controller.programs.openProgram(program);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProgramEditorScreen(controller: controller),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.name,
                      style: TextStyle(color: t.keyText, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${program.steps.length} step${program.steps.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: t.keyText.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: t.keyText),
                onSelected: (action) => _onAction(context, action),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'run', child: Text('Run')),
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    switch (action) {
      case 'run':
        final error = controller.programs.run(program);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error ?? 'Ran ${program.name}: x = ${controller.xText}',
            ),
          ),
        );
      case 'rename':
        final name = await _promptForName(
          context,
          title: 'Rename program',
          initial: program.name,
        );
        if (name == null || name.isEmpty) return;
        controller.programs.renameProgram(program, name);
      case 'delete':
        controller.programs.deleteProgram(program);
    }
  }
}

/// Program editor: record/run/save, with a current-line pointer (tap a step
/// to select it — new keys are inserted right after it) and a dedicated
/// mini-keypad for control flow (LBL/GTO/GSB/RTN, 12 comparison tests) that
/// has no live-calculator equivalent, alongside the real [Keypad] reused
/// unmodified for ordinary keys.
///
/// Deliberately has no [Lcd] — while recording, a live numeric display would
/// be misleading, since nothing is actually computed per keystroke.
class ProgramEditorScreen extends StatelessWidget {
  const ProgramEditorScreen({super.key, required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.programs.stopRecording();
      },
      child: Scaffold(
        backgroundColor: t.background,
        appBar: AppBar(
          title: Text(controller.programs.current?.name ?? 'Program'),
          actions: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Run',
              onPressed: () => _run(context),
            ),
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save',
              onPressed: () {
                controller.programs.saveCurrent();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Saved')));
              },
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 640;
            final keypadHeight = compact ? 240.0 : 320.0;
            final controlHeight = compact ? 108.0 : 140.0;
            return ListenableBuilder(
              listenable: controller.programs,
              builder: (context, _) => _buildBody(
                context,
                compact: compact,
                keypadHeight: keypadHeight,
                controlHeight: controlHeight,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool compact,
    required double keypadHeight,
    required double controlHeight,
  }) {
    final t = controller.theme;
    final programs = controller.programs;
    final steps = programs.draftSteps;
    final recording = programs.isRecording;
    final selected = programs.selectedIndex;
    final prompt = programs.pendingPrompt;
    return Column(
      children: [
        Expanded(
          child: steps.isEmpty
              ? Center(
                  child: Text(
                    recording
                        ? 'Recording — tap keys below'
                        : 'No steps yet. Tap Record, then use the keypad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.keyText.withValues(alpha: 0.6)),
                  ),
                )
              : ListView.builder(
                  itemCount: steps.length,
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    final isSelected = index == selected;
                    return Material(
                      color: isSelected
                          ? t.accent.withValues(alpha: 0.18)
                          : Colors.transparent,
                      child: ListTile(
                        dense: true,
                        onTap: () => programs.selectStep(index),
                        leading: Text(
                          (index + 1).toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: t.keyText.withValues(alpha: 0.5),
                            fontFamily: 'monospace',
                          ),
                        ),
                        title: Text(
                          step.mnemonic,
                          style: TextStyle(
                            color: isSelected ? t.accent : t.keyText,
                            fontFamily: 'monospace',
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => programs.deleteStepAt(index),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (prompt != null)
          Container(
            width: double.infinity,
            color: t.accent.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Text(
              prompt,
              style: TextStyle(
                color: t.accent,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                if (recording) {
                  programs.stopRecording();
                } else {
                  programs.startRecording();
                }
              },
              icon: Icon(recording ? Icons.stop : Icons.fiber_manual_record),
              label: Text(recording ? 'Stop recording' : 'Record'),
              style: FilledButton.styleFrom(
                backgroundColor: recording ? Colors.red : t.accent,
                foregroundColor: recording ? Colors.white : t.accentText,
              ),
            ),
          ),
        ),
        SizedBox(
          height: controlHeight,
          child: _ControlFlowKeypad(controller: controller),
        ),
        SizedBox(
          height: keypadHeight,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Keypad(controller: controller, compact: compact),
          ),
        ),
      ],
    );
  }

  void _run(BuildContext context) {
    final program = controller.programs.current;
    if (program == null) return;
    final error = controller.programs.run(
      program.copyWith(steps: controller.programs.draftSteps),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'x = ${controller.xText}')));
  }
}

/// Control-flow keys (LBL/GTO/GSB/RTN, 12 comparison tests) with no
/// live-calculator equivalent, so they live here rather than on the main
/// [Keypad] — recording only, via [ProgramsController.recordKey].
class _ControlFlowKeypad extends StatelessWidget {
  const _ControlFlowKeypad({required this.controller});

  final CalculatorController controller;

  static const _rows = [
    [Opcode.lbl, Opcode.gto, Opcode.gsb, Opcode.rtn],
    [Opcode.xEq0, Opcode.xNe0, Opcode.xGt0, Opcode.xLt0],
    [Opcode.xGe0, Opcode.xLe0, Opcode.xEqY, Opcode.xNeY],
    [Opcode.xGtY, Opcode.xLtY, Opcode.xGeY, Opcode.xLeY],
  ];

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          for (final row in _rows)
            Expanded(
              child: Row(
                children: [
                  for (final op in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Material(
                          color: t.keyAltBackground,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => controller.programs.recordKey(op),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    opcodeLabel(op),
                                    style: TextStyle(
                                      color: t.keyAltText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
