import 'dart:ui';

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
}
