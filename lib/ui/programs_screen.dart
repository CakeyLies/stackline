import 'package:flutter/material.dart';

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

/// v1 straight-line program editor: record/run/save. Control-flow authoring
/// (LBL/GTO/GSB/RTN + comparison tests) lands in a later phase via a
/// dedicated mini-keypad alongside this same step list.
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
        body: ListenableBuilder(
          listenable: controller.programs,
          builder: (context, _) {
            final steps = controller.programs.draftSteps;
            final recording = controller.programs.isRecording;
            return Column(
              children: [
                Expanded(
                  child: steps.isEmpty
                      ? Center(
                          child: Text(
                            recording ? 'Recording — tap keys below' : 'No steps yet. Tap Record, then use the keypad.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: t.keyText.withValues(alpha: 0.6),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: steps.length,
                          itemBuilder: (context, index) {
                            final step = steps[index];
                            return ListTile(
                              dense: true,
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
                                  color: t.keyText,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              trailing: recording
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => controller.programs
                                          .deleteStepAt(index),
                                    ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (recording) {
                          controller.programs.stopRecording();
                        } else {
                          controller.programs.startRecording();
                        }
                      },
                      icon: Icon(
                        recording ? Icons.stop : Icons.fiber_manual_record,
                      ),
                      label: Text(recording ? 'Stop recording' : 'Record'),
                      style: FilledButton.styleFrom(
                        backgroundColor: recording ? Colors.red : t.accent,
                        foregroundColor: recording
                            ? Colors.white
                            : t.accentText,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Keypad(controller: controller, compact: true),
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
