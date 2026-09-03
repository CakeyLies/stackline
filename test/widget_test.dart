import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stackline/main.dart';
import 'package:stackline/model/display_style.dart';
import 'package:stackline/model/theme.dart';
import 'package:stackline/state/calculator_controller.dart';

void main() {
  testWidgets('2 ENTER 3 + = 5.0000', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = CalculatorController(prefs);

    await tester.pumpWidget(RpnEdgeApp(controller: controller));
    await tester.pump();

    expect(find.text('ENTER'), findsOneWidget);

    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('ENTER'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('+'));
    await tester.pump();

    expect(find.text('5.0000'), findsOneWidget);
  });

  testWidgets('every display style renders without error', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = CalculatorController(prefs);

    await tester.pumpWidget(RpnEdgeApp(controller: controller));
    await tester.pump();

    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('.'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('CHS'));
    await tester.pump();

    for (final style in DisplayStyle.values) {
      controller.setDisplayStyle(style);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'style=$style');
    }

    // Divide-by-zero error message must fall back to plain text in every style.
    controller.clearAll();
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('÷'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('every theme + display style combo renders without error', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = CalculatorController(prefs);

    await tester.pumpWidget(RpnEdgeApp(controller: controller));
    await tester.pump();

    for (final preset in CalcTheme.presets) {
      controller.setTheme(preset);
      for (final style in DisplayStyle.values) {
        controller.setDisplayStyle(style);
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${preset.name} / $style',
        );
      }
    }
  });

  testWidgets(
    'landscape and compact-landscape layouts render without overflow',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = CalculatorController(prefs);

      final sizes = <Size>[
        const Size(800, 400), // typical landscape phone
        const Size(600, 300), // short/compact landscape pop-up window
        const Size(1024, 500), // wide tablet-ish landscape
      ];

      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(RpnEdgeApp(controller: controller));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'size=$size');

        for (final style in DisplayStyle.values) {
          controller.setDisplayStyle(style);
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'size=$size style=$style',
          );
        }
        controller.setDisplayStyle(DisplayStyle.classic);
      }
    },
  );

  testWidgets('landscape unfolds shifted keys instead of using SHIFT', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = CalculatorController(prefs);

    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(RpnEdgeApp(controller: controller));
    await tester.pump();

    // No SHIFT toggle in landscape.
    expect(find.text('SHIFT'), findsNothing);

    // Both the primary and previously-shifted labels exist as their own keys.
    expect(find.text('LOG'), findsOneWidget);
    expect(find.text('10ˣ'), findsOneWidget);
    expect(find.text('SIN'), findsOneWidget);
    expect(find.text('ASIN'), findsOneWidget);
    expect(find.text('STO'), findsOneWidget);
    expect(find.text('RCL'), findsOneWidget);

    // yˣ is directly tappable with no shift press needed: 2 ENTER 3 yˣ = 8.
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('ENTER'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('yˣ'));
    await tester.pump();

    expect(find.text('8.0000'), findsOneWidget);
  });

  testWidgets(
    'arithmetic operator keys use the accent/accentText contrast pairing',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = CalculatorController(prefs);

      await tester.pumpWidget(RpnEdgeApp(controller: controller));
      await tester.pump();

      for (final preset in CalcTheme.presets) {
        controller.setTheme(preset);
        await tester.pump();

        for (final label in ['+', '−', '×', '÷']) {
          final textFinder = find.text(label);
          expect(
            textFinder,
            findsOneWidget,
            reason: '$label on ${preset.name}',
          );

          final text = tester.widget<Text>(textFinder);
          expect(
            text.style?.color,
            preset.accentText,
            reason: '$label foreground on ${preset.name}',
          );

          final material = tester.widget<Material>(
            find
                .ancestor(of: textFinder, matching: find.byType(Material))
                .first,
          );
          expect(
            material.color,
            preset.accent,
            reason: '$label background on ${preset.name}',
          );
        }
      }
    },
  );
}
