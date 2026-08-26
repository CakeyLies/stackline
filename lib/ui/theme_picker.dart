import 'package:flutter/material.dart';

import '../model/display_style.dart';
import '../model/theme.dart';
import '../state/calculator_controller.dart';
import 'segment_display.dart';

class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key, required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final current = controller.theme.name;
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Display style',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              SizedBox(
                height: 104,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final style in DisplayStyle.values)
                      _StyleTile(
                        style: style,
                        theme: controller.theme,
                        selected: controller.displayStyle == style,
                        onTap: () => controller.setDisplayStyle(style),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Color theme',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              for (final preset in CalcTheme.presets)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _ThemeTile(
                    preset: preset,
                    selected: preset.name == current,
                    onTap: () => controller.setTheme(preset),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final CalcTheme preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: preset.keyBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  preset.name,
                  style: TextStyle(color: preset.keyText, fontSize: 16),
                ),
              ),
              _Swatch(color: preset.lcdBackground),
              _Swatch(color: preset.keyBackground),
              _Swatch(color: preset.accent),
              const SizedBox(width: 12),
              if (selected)
                Icon(Icons.check_circle, color: preset.accent)
              else
                Icon(
                  Icons.circle_outlined,
                  color: preset.keyText.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.style,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final DisplayStyle style;
  final CalcTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = resolveDisplayColors(style, theme);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: theme.keyBackground,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 92,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? theme.accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.border, width: 1.5),
                    ),
                    child: style == DisplayStyle.classic
                        ? Text(
                            '8.8',
                            style: TextStyle(
                              color: colors.lit,
                              fontFamily: 'monospace',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : SegmentedNumber(
                            text: '8.8',
                            style: style,
                            litColor: colors.lit,
                            unlitColor: colors.unlit,
                            height: 22,
                            glowStrength: colors.glow,
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  style.label,
                  style: TextStyle(
                    color: theme.keyText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}
