import 'package:flutter/material.dart';

import '../state/calculator_controller.dart';
import '../state/functions_controller.dart';
import 'keypad.dart';

/// The saved-functions menu: create, open, rename, delete.
class FunctionsListScreen extends StatelessWidget {
  const FunctionsListScreen({super.key, required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        title: const Text('Functions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New function',
            onPressed: () => _createFunction(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller.functions,
        builder: (context, _) {
          final fns = controller.functions.saved;
          if (fns.isEmpty) {
            return Center(
              child: Text(
                'No functions yet.\nTap + to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.keyText.withValues(alpha: 0.6)),
              ),
            );
          }
          return ListView(
            children: [
              for (final fn in fns)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _FunctionTile(controller: controller, fn: fn),
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createFunction(BuildContext context) async {
    final name = await _promptForName(context, title: 'New function');
    if (name == null || name.isEmpty) return;
    controller.functions.newFunction(name);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FunctionEditorScreen(controller: controller),
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
        decoration: const InputDecoration(hintText: 'Function name'),
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

class _FunctionTile extends StatelessWidget {
  const _FunctionTile({required this.controller, required this.fn});

  final CalculatorController controller;
  final CalcFunction fn;

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    return Material(
      color: t.keyBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          controller.functions.openFunction(fn);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FunctionEditorScreen(controller: controller),
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
                      fn.name,
                      style: TextStyle(color: t.keyText, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'y = ${fn.body.toDisplayString()}',
                      style: TextStyle(
                        color: t.keyText.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: t.keyText),
                onSelected: (action) => _onAction(context, action),
                itemBuilder: (context) => const [
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
      case 'rename':
        final name = await _promptForName(
          context,
          title: 'Rename function',
          initial: fn.name,
        );
        if (name == null || name.isEmpty) return;
        controller.functions.renameFunction(fn, name);
      case 'delete':
        controller.functions.deleteFunction(fn);
    }
  }
}

/// Function editor: build `y = f(x)` symbolically using the real keypad
/// (routed through `Keypad`'s symbolic-mode branch instead of live
/// calculation), plus a dedicated "x" chip for the one affordance with no
/// live-keypad equivalent.
///
/// The 4-line expression-stack panel is its own small widget rather than
/// [Lcd] — [Lcd]'s segment-glyph rendering is fundamentally numeric and
/// can't render something like `sin(x)`.
class FunctionEditorScreen extends StatelessWidget {
  const FunctionEditorScreen({super.key, required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.functions.stopEditing();
      },
      child: Scaffold(
        backgroundColor: t.background,
        appBar: AppBar(
          title: Text(controller.functions.current?.name ?? 'Function'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save',
              onPressed: () {
                controller.functions.saveCurrent();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Saved')));
              },
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 640;
            return ListenableBuilder(
              listenable: controller.functions,
              builder: (context, _) => _buildBody(context, compact: compact),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, {required bool compact}) {
    final t = controller.theme;
    final fns = controller.functions;
    final editing = fns.isEditing;
    return Column(
      children: [
        _ExpressionStackPanel(controller: controller),
        if (fns.error != null)
          Container(
            width: double.infinity,
            color: Colors.red.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Text(
              fns.error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    if (editing) {
                      fns.stopEditing();
                    } else {
                      fns.startEditing();
                    }
                  },
                  icon: Icon(editing ? Icons.stop : Icons.edit),
                  label: Text(editing ? 'Stop editing' : 'Edit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: editing ? Colors.red : t.accent,
                    foregroundColor: editing ? Colors.white : t.accentText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                key: const Key('pushVariableChip'),
                width: 64,
                height: 48,
                child: Material(
                  color: t.keyAltBackground,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: fns.pushVariable,
                    child: Center(
                      child: Text(
                        'x',
                        style: TextStyle(
                          color: t.keyAltText,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: compact ? 260 : 340,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Keypad(controller: controller, compact: compact),
          ),
        ),
      ],
    );
  }
}

class _ExpressionStackPanel extends StatelessWidget {
  const _ExpressionStackPanel({required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    final fns = controller.functions;
    final dim = t.lcdText.withValues(alpha: 0.62);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.lcdBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.lcdBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _line(fns.tDisplay, dim, 13),
          _line(fns.zDisplay, dim, 13),
          _line(fns.yDisplay, dim, 13),
          const SizedBox(height: 2),
          _line(fns.xDisplay, t.lcdText, 22, bold: true),
        ],
      ),
    );
  }

  Widget _line(String text, Color color, double fontSize, {bool bold = false}) {
    return SizedBox(
      height: fontSize + 8,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
