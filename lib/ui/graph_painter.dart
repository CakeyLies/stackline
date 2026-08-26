import 'package:flutter/material.dart';

import '../model/expr.dart';

/// Plots [function] (and optionally [derivative]) over `xMin..xMax`, with
/// gridlines and axes, sampling [samples] points via [Expr.eval].
///
/// The Y range auto-fits using the 5th-95th percentile of sampled values
/// rather than the raw min/max, so a single asymptote (e.g. `tan(x)` near
/// pi/2) doesn't blow the visible range out to where the interesting part
/// of the curve is invisible.
class GraphPainter extends CustomPainter {
  const GraphPainter({
    required this.function,
    required this.xMin,
    required this.xMax,
    required this.axisColor,
    required this.gridColor,
    required this.curveColor,
    this.derivative,
    this.derivativeColor,
    this.samples = 400,
  });

  final Expr function;
  final Expr? derivative;
  final double xMin;
  final double xMax;
  final Color axisColor;
  final Color gridColor;
  final Color curveColor;
  final Color? derivativeColor;
  final int samples;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final xs = List<double>.generate(
      samples,
      (i) => xMin + (xMax - xMin) * i / (samples - 1),
    );

    final ys = <double>[];
    for (final x in xs) {
      final v = function.eval(x);
      if (v.isFinite) ys.add(v);
      if (derivative != null) {
        final dv = derivative!.eval(x);
        if (dv.isFinite) ys.add(dv);
      }
    }

    double yMin;
    double yMax;
    if (ys.isEmpty) {
      yMin = -1;
      yMax = 1;
    } else {
      final sorted = List<double>.of(ys)..sort();
      final loIndex = (sorted.length * 0.05).floor().clamp(
        0,
        sorted.length - 1,
      );
      final hiIndex = (sorted.length * 0.95).ceil().clamp(0, sorted.length - 1);
      yMin = sorted[loIndex];
      yMax = sorted[hiIndex];
      if (yMin == yMax) {
        yMin -= 1;
        yMax += 1;
      }
      final pad = (yMax - yMin) * 0.1;
      yMin -= pad;
      yMax += pad;
    }

    double sx(double x) => (x - xMin) / (xMax - xMin) * size.width;
    double sy(double y) =>
        size.height - (y - yMin) / (yMax - yMin) * size.height;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final gx = xMin + (xMax - xMin) * i / 4;
      canvas.drawLine(
        Offset(sx(gx), 0),
        Offset(sx(gx), size.height),
        gridPaint,
      );
      final gy = yMin + (yMax - yMin) * i / 4;
      canvas.drawLine(Offset(0, sy(gy)), Offset(size.width, sy(gy)), gridPaint);
    }

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5;
    if (xMin <= 0 && xMax >= 0) {
      canvas.drawLine(Offset(sx(0), 0), Offset(sx(0), size.height), axisPaint);
    }
    if (yMin <= 0 && yMax >= 0) {
      canvas.drawLine(Offset(0, sy(0)), Offset(size.width, sy(0)), axisPaint);
    }

    _drawCurve(canvas, function, xs, sx, sy, curveColor, 2.5);
    final dColor = derivativeColor;
    if (derivative != null && dColor != null) {
      _drawCurve(canvas, derivative!, xs, sx, sy, dColor, 2);
    }
  }

  void _drawCurve(
    Canvas canvas,
    Expr f,
    List<double> xs,
    double Function(double) sx,
    double Function(double) sy,
    Color color,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    var needsMove = true;
    for (final x in xs) {
      final v = f.eval(x);
      if (!v.isFinite) {
        needsMove = true;
        continue;
      }
      final p = Offset(sx(x), sy(v));
      if (needsMove) {
        path.moveTo(p.dx, p.dy);
        needsMove = false;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) =>
      oldDelegate.function != function ||
      oldDelegate.derivative != derivative ||
      oldDelegate.xMin != xMin ||
      oldDelegate.xMax != xMax ||
      oldDelegate.curveColor != curveColor ||
      oldDelegate.derivativeColor != derivativeColor;
}
