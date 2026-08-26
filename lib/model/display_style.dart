import 'package:flutter/material.dart';

import 'theme.dart';

enum DisplayStyle { classic, sevenSegment, vfd, dotMatrix }

extension DisplayStyleLabel on DisplayStyle {
  String get label => switch (this) {
    DisplayStyle.classic => 'Classic',
    DisplayStyle.sevenSegment => '7-Segment',
    DisplayStyle.vfd => 'VFD',
    DisplayStyle.dotMatrix => 'Dot Matrix',
  };
}

@immutable
class DisplayColors {
  const DisplayColors({
    required this.background,
    required this.border,
    required this.lit,
    required this.unlit,
    required this.glow,
  });

  final Color background;
  final Color border;
  final Color lit;
  final Color unlit;
  final double glow;
}

/// Resolves the LCD panel + glyph colors for a given display style.
///
/// Classic/7-segment/dot-matrix stay tinted by the active [CalcTheme] so
/// they combine with any color preset. VFD intentionally overrides the
/// panel to the near-black glass + cyan glow of a real vacuum-fluorescent
/// tube, since that fixed look is the point of choosing it.
DisplayColors resolveDisplayColors(DisplayStyle style, CalcTheme theme) {
  switch (style) {
    case DisplayStyle.classic:
      return DisplayColors(
        background: theme.lcdBackground,
        border: theme.lcdBorder,
        lit: theme.lcdText,
        unlit: theme.lcdText,
        glow: 0,
      );
    case DisplayStyle.sevenSegment:
      return DisplayColors(
        background: theme.lcdBackground,
        border: theme.lcdBorder,
        lit: theme.lcdText,
        unlit: theme.lcdText.withValues(alpha: 0.12),
        glow: 0.45,
      );
    case DisplayStyle.dotMatrix:
      return DisplayColors(
        background: theme.lcdBackground,
        border: theme.lcdBorder,
        lit: theme.lcdText,
        unlit: theme.lcdText.withValues(alpha: 0.16),
        glow: 0.2,
      );
    case DisplayStyle.vfd:
      return const DisplayColors(
        background: Color(0xFF04090A),
        border: Color(0xFF1D3B39),
        lit: Color(0xFF3BFCE0),
        unlit: Color(0xFF163634),
        glow: 1.0,
      );
  }
}

final RegExp _segmentTextPattern = RegExp(r'^[0-9.\-eE ]*$');

/// Whether [s] contains only characters the segment/dot-matrix glyph set
/// can render (digits, sign, decimal point, exponent marker). Error
/// messages and other words fall back to plain text.
bool isSegmentText(String s) => _segmentTextPattern.hasMatch(s);
