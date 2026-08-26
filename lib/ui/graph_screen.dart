import 'package:flutter/material.dart';

import '../model/expr.dart';
import '../state/calculator_controller.dart';
import 'graph_painter.dart';

/// Plots [function] over an adjustable X range, with an optional overlay
/// of its derivative. Fixed-range with manual min/max fields for v1 —
/// pan/zoom is a stretch, not required to be useful.
class GraphScreen extends StatefulWidget {
  const GraphScreen({
    super.key,
    required this.controller,
    required this.function,
    this.title = 'Graph',
  });

  final CalculatorController controller;
  final Expr function;
  final String title;

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final _minController = TextEditingController(text: '-10');
  final _maxController = TextEditingController(text: '10');
  double _xMin = -10;
  double _xMax = 10;
  bool _showDerivative = false;

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _applyRange() {
    final min = double.tryParse(_minController.text);
    final max = double.tryParse(_maxController.text);
    if (min == null || max == null || min >= max) return;
    setState(() {
      _xMin = min;
      _xMax = max;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.controller.theme;
    final derivative = _showDerivative
        ? widget.function.differentiate().simplify()
        : null;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'X min',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyRange(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'X max',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyRange(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Apply range',
                  onPressed: _applyRange,
                ),
              ],
            ),
          ),
          SwitchListTile(
            dense: true,
            title: Text('Show derivative', style: TextStyle(color: t.keyText)),
            value: _showDerivative,
            onChanged: (v) => setState(() => _showDerivative = v),
            activeThumbColor: t.accent,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox.expand(
                child: CustomPaint(
                  painter: GraphPainter(
                    function: widget.function,
                    derivative: derivative,
                    xMin: _xMin,
                    xMax: _xMax,
                    axisColor: t.keyText.withValues(alpha: 0.6),
                    gridColor: t.keyText.withValues(alpha: 0.15),
                    curveColor: t.accent,
                    derivativeColor: t.keyAltText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
