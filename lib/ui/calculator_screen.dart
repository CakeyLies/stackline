import 'package:flutter/material.dart';

import '../state/calculator_controller.dart';
import 'keypad.dart';
import 'lcd.dart';
import 'programs_screen.dart';
import 'theme_picker.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key, required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final compact =
                constraints.maxWidth < 340 || constraints.maxHeight < 520;

            return Column(
              children: [
                _TopBar(controller: controller),
                RepaintBoundary(
                  child: Lcd(controller: controller, compact: compact),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 4 : 8),
                    child: RepaintBoundary(
                      child: Keypad(
                        controller: controller,
                        compact: compact,
                        landscape: isLandscape,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.theme;
    final fg = t.keyText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            'RPN',
            style: TextStyle(
              color: fg.withValues(alpha: 0.55),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          _BarButton(
            label: controller.angleLabel,
            color: fg,
            onTap: controller.cycleAngleMode,
          ),
          _BarButton(
            label: controller.displayModeLabel,
            color: fg,
            onTap: controller.cycleDisplayMode,
          ),
          _BarButton(
            label: 'D${controller.engine.displayDigits}',
            color: fg,
            onTap: controller.cycleDisplayDigits,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.apps, color: t.accent),
            tooltip: 'Menu',
            onSelected: (value) {
              switch (value) {
                case 'themes':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ThemePickerScreen(controller: controller),
                    ),
                  );
                case 'programs':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProgramsListScreen(controller: controller),
                    ),
                  );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'themes', child: Text('Themes')),
              PopupMenuItem(value: 'programs', child: Text('Programs')),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
      ),
      child: Text(
        label,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}
