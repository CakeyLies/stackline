import 'dart:ui';

import 'package:flutter/material.dart';

import '../model/display_style.dart';

const Map<String, Set<String>> _segments = {
  '0': {'a', 'b', 'c', 'd', 'e', 'f'},
  '1': {'b', 'c'},
  '2': {'a', 'b', 'g', 'e', 'd'},
  '3': {'a', 'b', 'g', 'c', 'd'},
  '4': {'f', 'g', 'b', 'c'},
  '5': {'a', 'f', 'g', 'c', 'd'},
  '6': {'a', 'f', 'g', 'e', 'd', 'c'},
  '7': {'a', 'b', 'c'},
  '8': {'a', 'b', 'c', 'd', 'e', 'f', 'g'},
  '9': {'a', 'b', 'c', 'd', 'f', 'g'},
  '-': {'g'},
  'e': {'a', 'f', 'g', 'e', 'd'},
  'E': {'a', 'f', 'g', 'e', 'd'},
  ' ': {},
};

const Map<String, List<String>> _dotFont = {
  '0': ['.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'],
  '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
  '2': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
  '3': ['.###.', '#...#', '....#', '..##.', '....#', '#...#', '.###.'],
  '4': ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'],
  '5': ['#####', '#....', '#....', '####.', '....#', '#...#', '.###.'],
  '6': ['..##.', '.#...', '#....', '####.', '#...#', '#...#', '.###.'],
  '7': ['#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'],
  '8': ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'],
  '9': ['.###.', '#...#', '#...#', '.####', '....#', '...#.', '.##..'],
  '-': ['.....', '.....', '.....', '#####', '.....', '.....', '.....'],
  '.': ['.....', '.....', '.....', '.....', '.....', '..##.', '..##.'],
  'e': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
  'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
  ' ': ['.....', '.....', '.....', '.....', '.....', '.....', '.....'],
};

double _glyphWidth(String ch, DisplayStyle style, double height) {
  if (style == DisplayStyle.dotMatrix) return height * (ch == '.' ? 0.3 : 0.62);
  if (ch == '.') return height * 0.24;
  return height * 0.56;
}

double _lineWidth(String text, DisplayStyle style, double height) {
  if (text.isEmpty) return 0;
  final gap = height * 0.07;
  var w = 0.0;
  for (var i = 0; i < text.length; i++) {
    if (i > 0) w += gap;
    w += _glyphWidth(text[i], style, height);
  }
  return w;
}

/// One drawable primitive within a line of glyphs, tagged with whether it's
/// lit. Kept as plain data so a whole line's shapes can be built once and
/// drawn in three flat passes (unlit, glow, lit) instead of per-glyph.
class _Shape {
  const _Shape.rrect(this.rrect, this.lit) : center = null, radius = 0;
  const _Shape.circle(this.center, this.radius, this.lit) : rrect = null;

  final RRect? rrect;
  final Offset? center;
  final double radius;
  final bool lit;

  void draw(Canvas canvas, Paint paint) {
    final r = rrect;
    if (r != null) {
      canvas.drawRRect(r, paint);
    } else {
      canvas.drawCircle(center!, radius, paint);
    }
  }
}

List<_Shape> _sevenSegShapes(
  Offset origin,
  double w,
  double h,
  Set<String> lit,
) {
  final thickness = h * 0.13;
  final margin = w * 0.10;
  final vMargin = h * 0.04;
  final midY = origin.dy + h / 2;
  final radius = Radius.circular(thickness * 0.4);
  final leftX = origin.dx + margin;
  final rightX = origin.dx + w - margin - thickness;
  final innerLeft = origin.dx + margin + thickness * 0.55;
  final innerRight = origin.dx + w - margin - thickness * 0.55;
  final top = origin.dy;
  final bottom = origin.dy + h;

  final rects = <String, RRect>{
    'a': RRect.fromLTRBR(
      innerLeft,
      top + vMargin,
      innerRight,
      top + vMargin + thickness,
      radius,
    ),
    'g': RRect.fromLTRBR(
      innerLeft,
      midY - thickness / 2,
      innerRight,
      midY + thickness / 2,
      radius,
    ),
    'd': RRect.fromLTRBR(
      innerLeft,
      bottom - vMargin - thickness,
      innerRight,
      bottom - vMargin,
      radius,
    ),
    'f': RRect.fromLTRBR(
      leftX,
      top + vMargin + thickness * 0.5,
      leftX + thickness,
      midY + thickness * 0.3,
      radius,
    ),
    'e': RRect.fromLTRBR(
      leftX,
      midY - thickness * 0.3,
      leftX + thickness,
      bottom - vMargin - thickness * 0.5,
      radius,
    ),
    'b': RRect.fromLTRBR(
      rightX,
      top + vMargin + thickness * 0.5,
      rightX + thickness,
      midY + thickness * 0.3,
      radius,
    ),
    'c': RRect.fromLTRBR(
      rightX,
      midY - thickness * 0.3,
      rightX + thickness,
      bottom - vMargin - thickness * 0.5,
      radius,
    ),
  };
  return [
    for (final e in rects.entries) _Shape.rrect(e.value, lit.contains(e.key)),
  ];
}

List<_Shape> _dotShape(Offset origin, double w, double h) {
  final r = w * 0.42;
  final center = Offset(origin.dx + w / 2, origin.dy + h - r * 1.1);
  return [_Shape.circle(center, r, true)];
}

List<_Shape> _dotMatrixShapes(
  Offset origin,
  double w,
  double h,
  List<String> rows,
) {
  const cols = 5;
  final rowCount = rows.length;
  final cellW = w / cols;
  final cellH = h / rowCount;
  final r = (cellW < cellH ? cellW : cellH) * 0.38;
  final shapes = <_Shape>[];
  for (var row = 0; row < rowCount; row++) {
    final line = rows[row];
    for (var col = 0; col < cols; col++) {
      final on = col < line.length && line[col] == '#';
      final center = Offset(
        origin.dx + cellW * (col + 0.5),
        origin.dy + cellH * (row + 0.5),
      );
      shapes.add(_Shape.circle(center, r, on));
    }
  }
  return shapes;
}

/// Renders [text] as glowing/segmented glyphs for [style]. Callers should
/// only use this for strings that pass [isSegmentText] — unsupported
/// characters (e.g. letters in an error message) simply render blank.
///
/// The whole line is drawn by a single [CustomPainter] so the glow effect
/// only needs one blurred compositing pass per line (see
/// [_SegmentedLinePainter]), not one per segment/dot — that's what keeps
/// Seven-Segment and Dot Matrix (up to 35 dots per character) fast.
class SegmentedNumber extends StatelessWidget {
  const SegmentedNumber({
    super.key,
    required this.text,
    required this.style,
    required this.litColor,
    required this.unlitColor,
    required this.height,
    this.glowStrength = 0,
  });

  final String text;
  final DisplayStyle style;
  final Color litColor;
  final Color unlitColor;
  final double height;
  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _lineWidth(text, style, height),
      height: height,
      child: CustomPaint(
        painter: _SegmentedLinePainter(
          text: text,
          style: style,
          litColor: litColor,
          unlitColor: unlitColor,
          glowStrength: glowStrength,
          cellHeight: height,
        ),
      ),
    );
  }
}

class _SegmentedLinePainter extends CustomPainter {
  const _SegmentedLinePainter({
    required this.text,
    required this.style,
    required this.litColor,
    required this.unlitColor,
    required this.glowStrength,
    required this.cellHeight,
  });

  final String text;
  final DisplayStyle style;
  final Color litColor;
  final Color unlitColor;
  final double glowStrength;
  final double cellHeight;

  List<_Shape> _buildShapes() {
    final shapes = <_Shape>[];
    final gap = cellHeight * 0.07;
    var x = 0.0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      final w = _glyphWidth(ch, style, cellHeight);
      final origin = Offset(x, 0);
      if (style == DisplayStyle.dotMatrix) {
        shapes.addAll(
          _dotMatrixShapes(
            origin,
            w,
            cellHeight,
            _dotFont[ch] ?? _dotFont[' ']!,
          ),
        );
      } else if (ch == '.') {
        shapes.addAll(_dotShape(origin, w, cellHeight));
      } else {
        shapes.addAll(
          _sevenSegShapes(origin, w, cellHeight, _segments[ch] ?? const {}),
        );
      }
      x += w + gap;
    }
    return shapes;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shapes = _buildShapes();

    final unlitPaint = Paint()..color = unlitColor;
    for (final s in shapes) {
      if (!s.lit) s.draw(canvas, unlitPaint);
    }

    if (glowStrength > 0) {
      final strength = glowStrength.clamp(0.0, 1.0);
      final sigma = cellHeight * 0.11 * strength;
      // One blurred layer for the whole line instead of a MaskFilter per
      // shape — collapses what used to be dozens of independent Gaussian
      // blurs (worst case: 35 dots x N characters) into a single composite.
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );
      final glowPaint = Paint()
        ..color = litColor.withValues(alpha: 0.35 + 0.45 * strength);
      for (final s in shapes) {
        if (s.lit) s.draw(canvas, glowPaint);
      }
      canvas.restore();
    }

    final litPaint = Paint()..color = litColor;
    for (final s in shapes) {
      if (s.lit) s.draw(canvas, litPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedLinePainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.litColor != litColor ||
      oldDelegate.unlitColor != unlitColor ||
      oldDelegate.glowStrength != glowStrength ||
      oldDelegate.cellHeight != cellHeight;
}
