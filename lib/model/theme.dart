import 'package:flutter/material.dart';

@immutable
class CalcTheme {
  final String name;
  final Color background;
  final Color lcdBackground;
  final Color lcdText;
  final Color lcdBorder;
  final Color keyBackground;
  final Color keyText;
  final Color keyAltBackground;
  final Color keyAltText;
  final Color accent;
  final Color accentText;
  final Brightness brightness;
  final Color? accentGlow;

  const CalcTheme({
    required this.name,
    required this.background,
    required this.lcdBackground,
    required this.lcdText,
    required this.lcdBorder,
    required this.keyBackground,
    required this.keyText,
    required this.keyAltBackground,
    required this.keyAltText,
    required this.accent,
    required this.accentText,
    required this.brightness,
    this.accentGlow,
  });

  static const List<CalcTheme> presets = [
    CalcTheme(
      name: 'Classic 42S',
      background: Color(0xFF3A3226),
      lcdBackground: Color(0xFF9AA48F),
      lcdText: Color(0xFF1B1E17),
      lcdBorder: Color(0xFF5A5F55),
      keyBackground: Color(0xFF4A4030),
      keyText: Color(0xFFE8DCC0),
      keyAltBackground: Color(0xFF6B5A3A),
      keyAltText: Color(0xFFFFE8B0),
      accent: Color(0xFFB08D3E),
      accentText: Color(0xFF1B1408),
      brightness: Brightness.dark,
    ),
    CalcTheme(
      name: 'Voyager',
      background: Color(0xFF1B2A41),
      lcdBackground: Color(0xFFCDD6C4),
      lcdText: Color(0xFF1A2410),
      lcdBorder: Color(0xFF6B7A5C),
      keyBackground: Color(0xFF26364F),
      keyText: Color(0xFFE6EEF5),
      keyAltBackground: Color(0xFF3A4A63),
      keyAltText: Color(0xFFFFD77A),
      accent: Color(0xFFC9A13B),
      accentText: Color(0xFF20160A),
      brightness: Brightness.dark,
    ),
    CalcTheme(
      name: 'Dark OLED',
      background: Color(0xFF000000),
      lcdBackground: Color(0xFF0A0A0A),
      lcdText: Color(0xFFFF6A00),
      lcdBorder: Color(0xFF1F1F1F),
      keyBackground: Color(0xFF161616),
      keyText: Color(0xFFE6E6E6),
      keyAltBackground: Color(0xFF232323),
      keyAltText: Color(0xFFFF9E40),
      accent: Color(0xFFFF6A00),
      accentText: Color(0xFF000000),
      brightness: Brightness.dark,
    ),
    CalcTheme(
      name: 'Light',
      background: Color(0xFFF2F2F2),
      lcdBackground: Color(0xFFE8E8E8),
      lcdText: Color(0xFF1A1A1A),
      lcdBorder: Color(0xFFC0C0C0),
      keyBackground: Color(0xFFFFFFFF),
      keyText: Color(0xFF1A1A1A),
      keyAltBackground: Color(0xFFE3E3E3),
      keyAltText: Color(0xFF0A5CAD),
      accent: Color(0xFF0A5CAD),
      accentText: Color(0xFFFFFFFF),
      brightness: Brightness.light,
    ),
    CalcTheme(
      name: 'Terminal green',
      background: Color(0xFF0B0B0B),
      lcdBackground: Color(0xFF0F1F0F),
      lcdText: Color(0xFF33FF66),
      lcdBorder: Color(0xFF1A3A1A),
      keyBackground: Color(0xFF111111),
      keyText: Color(0xFF33FF66),
      keyAltBackground: Color(0xFF1A1A1A),
      keyAltText: Color(0xFF99FF99),
      accent: Color(0xFF33FF66),
      accentText: Color(0xFF000000),
      brightness: Brightness.dark,
    ),
    CalcTheme(
      name: 'Solarized',
      background: Color(0xFF002B36),
      lcdBackground: Color(0xFF073642),
      lcdText: Color(0xFF93A1A1),
      lcdBorder: Color(0xFF586E75),
      keyBackground: Color(0xFF073642),
      keyText: Color(0xFFEEE8D5),
      keyAltBackground: Color(0xFF586E75),
      keyAltText: Color(0xFFB58900),
      accent: Color(0xFFB58900),
      accentText: Color(0xFF002B36),
      brightness: Brightness.dark,
    ),
    CalcTheme(
      name: 'Portal 2',
      background: Color(0xFF0D1117),
      lcdBackground: Color(0xFFE9F7FF),
      lcdText: Color(0xFF0F1B1F),
      lcdBorder: Color(0xFF29C5FF),
      keyBackground: Color(0xFF20252D),
      keyText: Color(0xFFF3F6F8),
      keyAltBackground: Color(0xFF2B323C),
      keyAltText: Color(0xFFFF8A1E),
      accent: Color(0xFF29C5FF),
      accentText: Color(0xFF07171C),
      brightness: Brightness.dark,
      accentGlow: Color(0x8829C5FF),
    ),
    CalcTheme(
      name: 'Cyber Neon',
      background: Color(0xFF0B0B14),
      lcdBackground: Color(0xFF07060F),
      lcdText: Color(0xFF00F0FF),
      lcdBorder: Color(0xFFFF2BD6),
      keyBackground: Color(0xFF161425),
      keyText: Color(0xFFF2E9FF),
      keyAltBackground: Color(0xFF241E38),
      keyAltText: Color(0xFFFF2BD6),
      accent: Color(0xFF00F0FF),
      accentText: Color(0xFF07060F),
      brightness: Brightness.dark,
      accentGlow: Color(0x88FF2BD6),
    ),
    CalcTheme(
      name: 'Nixie',
      background: Color(0xFF1A120B),
      lcdBackground: Color(0xFF140D08),
      lcdText: Color(0xFFFFB347),
      lcdBorder: Color(0xFF6B4326),
      keyBackground: Color(0xFF2B1F14),
      keyText: Color(0xFFF3E3CC),
      keyAltBackground: Color(0xFF3A2A1A),
      keyAltText: Color(0xFFFFD27A),
      accent: Color(0xFFFF9642),
      accentText: Color(0xFF1A0E04),
      brightness: Brightness.dark,
      accentGlow: Color(0x77FF9642),
    ),
  ];

  static CalcTheme byName(String? name) {
    return presets.firstWhere(
      (t) => t.name == name,
      orElse: () => presets.first,
    );
  }
}
