import 'package:flutter/material.dart';

import '../state/calculator_controller.dart';
import 'functions_screen.dart';
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
            // "Compact" means the window is tight on its *short* side (a
            // narrow phone, or a small pop-up view) or its *long* side. In
            // landscape those map to maxHeight/maxWidth respectively — the
            // reverse of portrait — so pick the pair by orientation instead
            // of always testing maxWidth/maxHeight. Testing them unswapped
            // made every landscape phone register as compact (its short
            // side, maxHeight, is almost always under the portrait-tuned
            // 520 threshold) regardless of how much width was available.
            final shortSide = isLandscape
                ? constraints.maxHeight
                : constraints.maxWidth;
            final longSide = isLandscape
                ? constraints.maxWidth
                : constraints.maxHeight;
            final compact = shortSide < 340 || longSide < 520;

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
                case 'functions':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          FunctionsListScreen(controller: controller),
                    ),
                  );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'themes', child: Text('Themes')),
              PopupMenuItem(value: 'programs', child: Text('Programs')),
              PopupMenuItem(value: 'functions', child: Text('Functions')),
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
