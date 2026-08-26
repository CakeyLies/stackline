import 'package:flutter/material.dart';

import '../model/display_style.dart';
import '../state/calculator_controller.dart';
import 'segment_display.dart';

class Lcd extends StatelessWidget {
  const Lcd({super.key, required this.controller, this.compact = false});

  final CalculatorController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    final style = controller.displayStyle;
    final colors = resolveDisplayColors(style, t);
    final annunciators = <String>[
      controller.angleLabel,
      controller.displayLabel,
      if (controller.pendingLabel.isNotEmpty) controller.pendingLabel,
      if (controller.shift) 'SHIFT',
      if (controller.isRecordingProgram) 'REC',
      if (controller.isSymbolicEditing) 'f(x)',
    ];

    final dim = colors.lit.withValues(alpha: 0.62);
    final stackFontSize = compact ? 10.0 : 12.0;
    final xFontSize = compact ? 26.0 : 34.0;
    final annunciatorFontSize = compact ? 9.5 : 11.0;

    final shadows = <BoxShadow>[
      if (t.accentGlow != null)
        BoxShadow(color: t.accentGlow!, blurRadius: 18, spreadRadius: 0.5),
      if (colors.glow > 0)
        BoxShadow(
          color: colors.lit.withValues(alpha: 0.25 * colors.glow),
          blurRadius: 22 * colors.glow,
        ),
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(8, compact ? 4 : 8, 8, 0),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.border, width: 2),
        boxShadow: shadows,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _NumberLine(
            text: controller.tText,
            fontSize: stackFontSize,
            color: dim,
            unlitColor: colors.unlit,
            glowStrength: colors.glow * 0.6,
            displayStyle: style,
          ),
          _NumberLine(
            text: controller.zText,
            fontSize: stackFontSize,
            color: dim,
            unlitColor: colors.unlit,
            glowStrength: colors.glow * 0.6,
            displayStyle: style,
          ),
          _NumberLine(
            text: controller.yText,
            fontSize: stackFontSize,
            color: dim,
            unlitColor: colors.unlit,
            glowStrength: colors.glow * 0.6,
            displayStyle: style,
          ),
          SizedBox(height: compact ? 1 : 2),
          _NumberLine(
            text: controller.xText,
            fontSize: xFontSize,
            color: colors.lit,
            unlitColor: colors.unlit,
            glowStrength: colors.glow,
            displayStyle: style,
            bold: true,
          ),
          SizedBox(height: compact ? 2 : 4),
          Row(
            children: [
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Line(
                    text: annunciators.join(' '),
                    style: TextStyle(
                      color: dim,
                      fontFamily: 'monospace',
                      fontSize: annunciatorFontSize,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _Line(
                    text: 'LASTx ${controller.lastXText}',
                    style: TextStyle(
                      color: dim,
                      fontFamily: 'monospace',
                      fontSize: annunciatorFontSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One numeric stack line. Renders via [SegmentedNumber] when [displayStyle]
/// calls for it and [text] is representable that way; otherwise falls back
/// to plain monospace text (used for error messages like "Divide by 0").
class _NumberLine extends StatelessWidget {
  const _NumberLine({
    required this.text,
    required this.fontSize,
    required this.color,
    required this.unlitColor,
    required this.glowStrength,
    required this.displayStyle,
    this.bold = false,
  });

  final String text;
  final double fontSize;
  final Color color;
  final Color unlitColor;
  final double glowStrength;
  final DisplayStyle displayStyle;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final useSegments =
        displayStyle != DisplayStyle.classic && isSegmentText(text);
    return SizedBox(
      height: fontSize + 8,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: useSegments
            ? SegmentedNumber(
                text: text.isEmpty ? '0' : text,
                style: displayStyle,
                litColor: color,
                unlitColor: unlitColor,
                height: fontSize,
                glowStrength: glowStrength,
              )
            : Text(
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

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: (style.fontSize ?? 14) + 8,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(text, style: style),
      ),
    );
  }
}
