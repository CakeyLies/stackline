import 'package:flutter/material.dart';

import '../model/opcode.dart';
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
    this.opcode,
    this.shiftOpcode,
    this.digitValue,
  });

  final String label;
  final String? shiftLabel;
  final KeyKind kind;
  final VoidCallback action;
  final VoidCallback? shiftAction;
  final KeyIcon? icon;
  final KeyIcon? shiftIcon;
  final int flex;

  /// This key's identity in the shared program-recording vocabulary (see
  /// `lib/model/opcode.dart`). Null for keys with no program meaning
  /// (SHIFT itself).
  final Opcode? opcode;
  final Opcode? shiftOpcode;

  /// The digit this key enters, for [Opcode.digit] keys — carried alongside
  /// [opcode] since a program step needs to know *which* digit was pressed.
  final int? digitValue;
}

/// One calculator action's label/handler/icon, keyed by [Opcode] — the
/// single source of truth both [Keypad] layouts pull from, so every action
/// is wired (and opcode-tagged) exactly once instead of twice.
class _Spec {
  const _Spec(this.label, this.action, {this.icon});

  final String label;
  final VoidCallback action;
  final KeyIcon? icon;
}

Map<Opcode, _Spec> _specsFor(CalculatorController c) => {
  Opcode.reciprocal: _Spec('1/x', c.reciprocal),
  Opcode.power: _Spec('yˣ', c.power),
  Opcode.sqrt: _Spec('√x', c.sqrt),
  Opcode.root: _Spec('x√y', c.root),
  Opcode.square: _Spec('x²', c.square),
  Opcode.factorial: _Spec('n!', c.factorial),
  Opcode.log10: _Spec('LOG', c.log10),
  Opcode.tenToX: _Spec('10ˣ', c.tenToX),
  Opcode.ln: _Spec('LN', c.ln),
  Opcode.eToX: _Spec('eˣ', c.eToX),
  Opcode.sin: _Spec('SIN', c.sin),
  Opcode.asin: _Spec('ASIN', c.asin),
  Opcode.cos: _Spec('COS', c.cos),
  Opcode.acos: _Spec('ACOS', c.acos),
  Opcode.tan: _Spec('TAN', c.tan),
  Opcode.atan: _Spec('ATAN', c.atan),
  Opcode.percent: _Spec('%', c.percent),
  Opcode.percentChange: _Spec('Δ%', c.percentChange),
  Opcode.pi: _Spec('π', c.pushPi),
  Opcode.eConst: _Spec('e', c.pushE),
  Opcode.store: _Spec('STO', c.pressStore),
  Opcode.recall: _Spec('RCL', c.pressRecall),
  Opcode.swapXY: _Spec('', c.swapXY, icon: KeyIcon.swap),
  Opcode.rollDown: _Spec('R', c.rollDown, icon: KeyIcon.down),
  Opcode.rollUp: _Spec('R', c.rollUp, icon: KeyIcon.up),
  Opcode.lastX: _Spec('LASTx', c.lastXRecall),
  Opcode.clearX: _Spec('CLx', c.clearX),
  Opcode.divide: _Spec('÷', c.divide),
  Opcode.multiply: _Spec('×', c.multiply),
  Opcode.subtract: _Spec('−', c.subtract),
  Opcode.add: _Spec('+', c.add),
  Opcode.decimalPoint: _Spec('.', c.decimalPoint),
  Opcode.enterExponent: _Spec('E', c.enterExponent),
  Opcode.changeSign: _Spec('CHS', c.changeSign),
  Opcode.backspace: _Spec('DEL', c.backspace),
  Opcode.enter: _Spec('ENTER', c.enter),
};

/// Builds a folded (shift-pairing) key from the shared spec table.
_Key _k(
  Map<Opcode, _Spec> s,
  Opcode op,
  KeyKind kind, {
  Opcode? shiftOp,
  int flex = 1,
}) {
  final spec = s[op]!;
  final shiftSpec = shiftOp == null ? null : s[shiftOp];
  return _Key(
    spec.label,
    kind,
    spec.action,
    shiftLabel: shiftSpec?.label,
    shiftAction: shiftSpec?.action,
    icon: spec.icon,
    shiftIcon: shiftSpec?.icon,
    flex: flex,
    opcode: op,
    shiftOpcode: shiftOp,
  );
}

/// Builds an unfolded (no-shift, its own key) key from the shared spec table.
_Key _u(Map<Opcode, _Spec> s, Opcode op, KeyKind kind, {int flex = 1}) {
  final spec = s[op]!;
  return _Key(
    spec.label,
    kind,
    spec.action,
    icon: spec.icon,
    flex: flex,
    opcode: op,
  );
}

_Key _digitKey(CalculatorController c, int n, {int flex = 1}) => _Key(
  '$n',
  KeyKind.normal,
  () => c.digit(n),
  flex: flex,
  opcode: Opcode.digit,
  digitValue: n,
);

class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.controller,
    required this.compact,
    this.landscape = false,
  });

  final CalculatorController controller;
  final bool compact;
  final bool landscape;

  void _onKey(_Key key) {
    if (key.kind == KeyKind.shift) {
      controller.pressShift();
      return;
    }
    final shifted = controller.shift && key.shiftAction != null;

    if (controller.isRecordingProgram) {
      final opcode = shifted ? key.shiftOpcode : key.opcode;
      controller.consumeShift();
      if (opcode != null) {
        controller.programs.recordKey(opcode, digitValue: key.digitValue);
      }
      return;
    }

    controller.consumeShift();
    (shifted ? key.shiftAction! : key.action)();
  }

  List<List<_Key>> _foldedLayout(CalculatorController c) {
    final s = _specsFor(c);
    return [
      [
        _k(s, Opcode.reciprocal, KeyKind.alt, shiftOp: Opcode.power),
        _k(s, Opcode.sqrt, KeyKind.alt, shiftOp: Opcode.root),
        _k(s, Opcode.square, KeyKind.alt, shiftOp: Opcode.factorial),
        _k(s, Opcode.log10, KeyKind.alt, shiftOp: Opcode.tenToX),
        _k(s, Opcode.ln, KeyKind.alt, shiftOp: Opcode.eToX),
      ],
      [
        _k(s, Opcode.sin, KeyKind.alt, shiftOp: Opcode.asin),
        _k(s, Opcode.cos, KeyKind.alt, shiftOp: Opcode.acos),
        _k(s, Opcode.tan, KeyKind.alt, shiftOp: Opcode.atan),
        _k(s, Opcode.percent, KeyKind.alt, shiftOp: Opcode.percentChange),
        _k(s, Opcode.pi, KeyKind.alt, shiftOp: Opcode.eConst),
      ],
      [
        _k(s, Opcode.store, KeyKind.alt, shiftOp: Opcode.recall),
        _u(s, Opcode.swapXY, KeyKind.alt),
        _k(s, Opcode.rollDown, KeyKind.alt, shiftOp: Opcode.rollUp),
        _u(s, Opcode.lastX, KeyKind.alt),
        _u(s, Opcode.clearX, KeyKind.alt),
      ],
      [
        _digitKey(c, 7),
        _digitKey(c, 8),
        _digitKey(c, 9),
        _u(s, Opcode.divide, KeyKind.alt),
        _u(s, Opcode.multiply, KeyKind.alt),
      ],
      [
        _digitKey(c, 4),
        _digitKey(c, 5),
        _digitKey(c, 6),
        _u(s, Opcode.subtract, KeyKind.alt),
        _u(s, Opcode.add, KeyKind.alt),
      ],
      [
        _digitKey(c, 1),
        _digitKey(c, 2),
        _digitKey(c, 3),
        _u(s, Opcode.decimalPoint, KeyKind.normal),
        _u(s, Opcode.enterExponent, KeyKind.normal),
      ],
      [
        _digitKey(c, 0, flex: 2),
        _u(s, Opcode.changeSign, KeyKind.normal),
        _u(s, Opcode.backspace, KeyKind.alt),
        _Key('SHIFT', KeyKind.shift, c.pressShift),
      ],
      [_u(s, Opcode.enter, KeyKind.accent, flex: 5)],
    ];
  }

  /// Landscape has enough width to give every shifted function its own key
  /// instead of overloading a SHIFT toggle — same row count as the folded
  /// layout, just wider rows where a key used to carry two functions.
  List<List<_Key>> _unfoldedLayout(CalculatorController c) {
    final s = _specsFor(c);
    return [
      [
        _u(s, Opcode.reciprocal, KeyKind.alt),
        _u(s, Opcode.power, KeyKind.alt),
        _u(s, Opcode.sqrt, KeyKind.alt),
        _u(s, Opcode.root, KeyKind.alt),
        _u(s, Opcode.square, KeyKind.alt),
        _u(s, Opcode.factorial, KeyKind.alt),
        _u(s, Opcode.log10, KeyKind.alt),
        _u(s, Opcode.tenToX, KeyKind.alt),
        _u(s, Opcode.ln, KeyKind.alt),
        _u(s, Opcode.eToX, KeyKind.alt),
      ],
      [
        _u(s, Opcode.sin, KeyKind.alt),
        _u(s, Opcode.asin, KeyKind.alt),
        _u(s, Opcode.cos, KeyKind.alt),
        _u(s, Opcode.acos, KeyKind.alt),
        _u(s, Opcode.tan, KeyKind.alt),
        _u(s, Opcode.atan, KeyKind.alt),
        _u(s, Opcode.percent, KeyKind.alt),
        _u(s, Opcode.percentChange, KeyKind.alt),
        _u(s, Opcode.pi, KeyKind.alt),
        _u(s, Opcode.eConst, KeyKind.alt),
      ],
      [
        _u(s, Opcode.store, KeyKind.alt),
        _u(s, Opcode.recall, KeyKind.alt),
        _u(s, Opcode.swapXY, KeyKind.alt),
        _u(s, Opcode.rollDown, KeyKind.alt),
        _u(s, Opcode.rollUp, KeyKind.alt),
        _u(s, Opcode.lastX, KeyKind.alt),
        _u(s, Opcode.clearX, KeyKind.alt),
      ],
      [
        _digitKey(c, 7),
        _digitKey(c, 8),
        _digitKey(c, 9),
        _u(s, Opcode.divide, KeyKind.alt),
        _u(s, Opcode.multiply, KeyKind.alt),
      ],
      [
        _digitKey(c, 4),
        _digitKey(c, 5),
        _digitKey(c, 6),
        _u(s, Opcode.subtract, KeyKind.alt),
        _u(s, Opcode.add, KeyKind.alt),
      ],
      [
        _digitKey(c, 1),
        _digitKey(c, 2),
        _digitKey(c, 3),
        _u(s, Opcode.decimalPoint, KeyKind.normal),
        _u(s, Opcode.enterExponent, KeyKind.normal),
      ],
      [
        _digitKey(c, 0, flex: 2),
        _u(s, Opcode.changeSign, KeyKind.normal),
        _u(s, Opcode.backspace, KeyKind.alt),
      ],
      [_u(s, Opcode.enter, KeyKind.accent, flex: 5)],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final layout = landscape
        ? _unfoldedLayout(controller)
        : _foldedLayout(controller);

    final padding = compact ? 2.5 : 5.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: landscape ? 920 : 460),
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
          fontWeight: spec.kind == KeyKind.accent
              ? FontWeight.bold
              : FontWeight.w600,
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
          child: CustomPaint(
            painter: _ArrowPainter(theme.accent, spec.shiftIcon!),
          ),
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
                  boxShadow: [
                    BoxShadow(color: glow, blurRadius: 16, spreadRadius: 1),
                  ],
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
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
    );
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

  Widget _rollContent(
    String label,
    KeyIcon icon,
    Color color,
    double fontSize,
  ) {
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
    );
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
        _arrow(
          canvas,
          paint,
          Offset(size.width * 0.08, size.height * 0.2),
          Offset(size.width * 0.92, size.height * 0.2),
        );
        _arrow(
          canvas,
          paint,
          Offset(size.width * 0.92, size.height * 0.8),
          Offset(size.width * 0.08, size.height * 0.8),
        );
      case KeyIcon.down:
        _arrow(
          canvas,
          paint,
          Offset(size.width * 0.5, size.height * 0.12),
          Offset(size.width * 0.5, size.height * 0.88),
        );
      case KeyIcon.up:
        _arrow(
          canvas,
          paint,
          Offset(size.width * 0.5, size.height * 0.88),
          Offset(size.width * 0.5, size.height * 0.12),
        );
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
