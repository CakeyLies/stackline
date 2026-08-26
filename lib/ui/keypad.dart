import 'package:flutter/material.dart';

import '../model/theme.dart';
import '../state/calculator_controller.dart';

enum KeyKind { normal, alt, accent, shift }

enum KeyIcon { swap, down, up }

class _Key {
  const _Key(
    this.label,
    this.kind,
    this.action, {
    this.shiftLabel,
    this.shiftAction,
    this.icon,
    this.shiftIcon,
    this.flex = 1,
  });

  final String label;
  final String? shiftLabel;
  final KeyKind kind;
  final VoidCallback action;
  final VoidCallback? shiftAction;
  final KeyIcon? icon;
  final KeyIcon? shiftIcon;
  final int flex;
}

class Keypad extends StatelessWidget {
  const Keypad({super.key, required this.controller, required this.compact});

  final CalculatorController controller;
  final bool compact;

  void _onKey(_Key key) {
    if (key.kind == KeyKind.shift) {
      controller.pressShift();
      return;
    }
    final shifted = controller.shift && key.shiftAction != null;
    controller.consumeShift();
    (shifted ? key.shiftAction! : key.action)();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final layout = <List<_Key>>[
      [
        _Key('1/x', KeyKind.alt, c.reciprocal, shiftLabel: 'yˣ', shiftAction: c.power),
        _Key('√x', KeyKind.alt, c.sqrt, shiftLabel: 'x√y', shiftAction: c.root),
        _Key('x²', KeyKind.alt, c.square, shiftLabel: 'n!', shiftAction: c.factorial),
        _Key('LOG', KeyKind.alt, c.log10, shiftLabel: '10ˣ', shiftAction: c.tenToX),
        _Key('LN', KeyKind.alt, c.ln, shiftLabel: 'eˣ', shiftAction: c.eToX),
      ],
      [
        _Key('SIN', KeyKind.alt, c.sin, shiftLabel: 'ASIN', shiftAction: c.asin),
        _Key('COS', KeyKind.alt, c.cos, shiftLabel: 'ACOS', shiftAction: c.acos),
        _Key('TAN', KeyKind.alt, c.tan, shiftLabel: 'ATAN', shiftAction: c.atan),
        _Key('%', KeyKind.alt, c.percent, shiftLabel: 'Δ%', shiftAction: c.percentChange),
        _Key('π', KeyKind.alt, c.pushPi, shiftLabel: 'e', shiftAction: c.pushE),
      ],
      [
        _Key('STO', KeyKind.alt, c.pressStore, shiftLabel: 'RCL', shiftAction: c.pressRecall),
        _Key('', KeyKind.alt, c.swapXY, icon: KeyIcon.swap),
        _Key('R', KeyKind.alt, c.rollDown, icon: KeyIcon.down, shiftIcon: KeyIcon.up, shiftAction: c.rollUp),
        _Key('LASTx', KeyKind.alt, c.lastXRecall),
        _Key('CLx', KeyKind.alt, c.clearX),
      ],
      [
        _Key('7', KeyKind.normal, () => c.digit(7)),
        _Key('8', KeyKind.normal, () => c.digit(8)),
        _Key('9', KeyKind.normal, () => c.digit(9)),
        _Key('÷', KeyKind.alt, c.divide),
        _Key('×', KeyKind.alt, c.multiply),
      ],
      [
        _Key('4', KeyKind.normal, () => c.digit(4)),
        _Key('5', KeyKind.normal, () => c.digit(5)),
        _Key('6', KeyKind.normal, () => c.digit(6)),
        _Key('−', KeyKind.alt, c.subtract),
        _Key('+', KeyKind.alt, c.add),
      ],
      [
        _Key('1', KeyKind.normal, () => c.digit(1)),
        _Key('2', KeyKind.normal, () => c.digit(2)),
        _Key('3', KeyKind.normal, () => c.digit(3)),
        _Key('.', KeyKind.normal, c.decimalPoint),
        _Key('E', KeyKind.normal, c.enterExponent),
      ],
      [
        _Key('0', KeyKind.normal, () => c.digit(0), flex: 2),
        _Key('CHS', KeyKind.normal, c.changeSign),
        _Key('DEL', KeyKind.alt, c.backspace),
        _Key('SHIFT', KeyKind.shift, c.pressShift),
      ],
      [
        _Key('ENTER', KeyKind.accent, c.enter, flex: 5),
      ],
    ];

    final padding = compact ? 2.5 : 5.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          children: [
            for (final row in layout)
              Expanded(
                child: Row(
                  children: [
                    for (final key in row)
                      _KeyButton(
                        spec: key,
                        controller: controller,
                        theme: controller.theme,
                        compact: compact,
                        padding: padding,
                        onPressed: () => _onKey(key),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.spec,
    required this.controller,
    required this.theme,
    required this.compact,
    required this.padding,
    required this.onPressed,
  });

  final _Key spec;
  final CalculatorController controller;
  final CalcTheme theme;
  final bool compact;
  final double padding;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shifted = controller.shift && spec.shiftAction != null;
    final label = shifted ? (spec.shiftLabel ?? spec.label) : spec.label;
    final icon = shifted ? (spec.shiftIcon ?? spec.icon) : spec.icon;

    final Color bg;
    final Color fg;
    switch (spec.kind) {
      case KeyKind.normal:
        bg = theme.keyBackground;
        fg = theme.keyText;
      case KeyKind.alt:
        bg = theme.keyAltBackground;
        fg = shifted ? theme.accent : theme.keyAltText;
      case KeyKind.accent:
        bg = theme.accent;
        fg = theme.accentText;
      case KeyKind.shift:
        if (controller.shift) {
          bg = theme.accent;
          fg = theme.accentText;
        } else {
          bg = theme.keyBackground;
          fg = theme.accent;
        }
    }

    final double fontSize = switch (spec.kind) {
      KeyKind.normal => compact ? 17 : 22,
      KeyKind.alt => compact ? 12 : 15,
      KeyKind.accent => compact ? 16 : 20,
      KeyKind.shift => compact ? 11 : 13,
    };

    final Widget main = switch (icon) {
      KeyIcon.swap => _swapContent(fg, fontSize),
      KeyIcon.down => _rollContent(label, KeyIcon.down, fg, fontSize),
      KeyIcon.up => _rollContent(label, KeyIcon.up, fg, fontSize),
      null => Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: spec.kind == KeyKind.accent ? FontWeight.bold : FontWeight.w600,
            color: fg,
            letterSpacing: 0.2,
          ),
        ),
    };

    Widget? hint;
    if (!shifted) {
      if (spec.shiftLabel != null) {
        hint = Text(
          spec.shiftLabel!,
          style: TextStyle(
            fontSize: compact ? 7 : 8.5,
            fontWeight: FontWeight.w600,
            color: theme.accent,
          ),
        );
      } else if (spec.shiftIcon != null) {
        hint = SizedBox(
          width: compact ? 9 : 11,
          height: compact ? 10 : 12,
          child: CustomPaint(painter: _ArrowPainter(theme.accent, spec.shiftIcon!)),
        );
      }
    }

    final glow = spec.kind == KeyKind.accent ? theme.accentGlow : null;

    return Expanded(
      flex: spec.flex,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Container(
          decoration: glow == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: glow, blurRadius: 16, spreadRadius: 1)],
                ),
          child: Material(
            color: bg,
            elevation: 2,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: main,
                      ),
                    ),
                  ),
                  if (hint != null)
                    Positioned(
                      top: compact ? 2 : 4,
                      right: compact ? 4 : 7,
                      child: hint,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _swapContent(Color color, double fontSize) {
    final arrowW = compact ? 20.0 : 26.0;
    final arrowH = compact ? 16.0 : 20.0;
    final textStyle = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('x', style: textStyle),
        SizedBox(width: compact ? 2 : 3),
        SizedBox(
          width: arrowW,
          height: arrowH,
          child: CustomPaint(painter: _ArrowPainter(color, KeyIcon.swap)),
        ),
        SizedBox(width: compact ? 2 : 3),
        Text('y', style: textStyle),
      ],
    );
  }

  Widget _rollContent(String label, KeyIcon icon, Color color, double fontSize) {
    final textStyle = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: textStyle),
        SizedBox(width: compact ? 2 : 3),
        SizedBox(
          width: compact ? 14 : 17,
          height: compact ? 16 : 19,
          child: CustomPaint(painter: _ArrowPainter(color, icon)),
        ),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color, this.icon);

  final Color color;
  final KeyIcon icon;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icon) {
      case KeyIcon.swap:
        _arrow(canvas, paint, Offset(size.width * 0.08, size.height * 0.2), Offset(size.width * 0.92, size.height * 0.2));
        _arrow(canvas, paint, Offset(size.width * 0.92, size.height * 0.8), Offset(size.width * 0.08, size.height * 0.8));
      case KeyIcon.down:
        _arrow(canvas, paint, Offset(size.width * 0.5, size.height * 0.12), Offset(size.width * 0.5, size.height * 0.88));
      case KeyIcon.up:
        _arrow(canvas, paint, Offset(size.width * 0.5, size.height * 0.88), Offset(size.width * 0.5, size.height * 0.12));
    }
  }

  void _arrow(Canvas canvas, Paint paint, Offset start, Offset end) {
    canvas.drawLine(start, end, paint);
    final vector = end - start;
    final length = vector.distance;
    if (length == 0) return;
    final unit = vector / length;
    final normal = Offset(-unit.dy, unit.dx);
    final headLength = length * 0.34;
    final base = end - unit * headLength;
    final half = headLength * 0.5;
    canvas.drawLine(end, base + normal * half, paint);
    canvas.drawLine(end, base - normal * half, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.icon != icon;
}
