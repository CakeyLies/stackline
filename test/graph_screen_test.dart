import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stackline/model/expr.dart';
import 'package:stackline/state/calculator_controller.dart';
import 'package:stackline/ui/graph_painter.dart';
import 'package:stackline/ui/graph_screen.dart';

const _x = VarExpr();

void main() {
  group('GraphScreen', () {
    testWidgets('renders a polynomial without exceptions', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = CalculatorController(prefs);

      final f = SubExpr(PowExpr(_x, const ConstExpr(2)), const ConstExpr(3));
      await tester.pumpWidget(
        MaterialApp(
          home: GraphScreen(
            controller: controller,
            function: f,
            title: 'x^2 - 3',
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders a trig function with the derivative overlay without exceptions',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final controller = CalculatorController(prefs);

        final f = SinExpr(_x);
        await tester.pumpWidget(
          MaterialApp(
            home: GraphScreen(
              controller: controller,
              function: f,
              title: 'sin(x)',
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Show derivative'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('applying a new X range re-renders without exceptions', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = CalculatorController(prefs);

      final f = CosExpr(_x);
      await tester.pumpWidget(
        MaterialApp(
          home: GraphScreen(controller: controller, function: f),
        ),
      );
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'X min'), '-3.14');
      await tester.enterText(find.widgetWithText(TextField, 'X max'), '3.14');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('an invalid range (min >= max) is ignored, not crashing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = CalculatorController(prefs);

      final f = _x;
      await tester.pumpWidget(
        MaterialApp(
          home: GraphScreen(controller: controller, function: f),
        ),
      );
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'X min'), '5');
      await tester.enterText(find.widgetWithText(TextField, 'X max'), '1');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('GraphPainter (direct paint)', () {
    void paintTo(GraphPainter painter, Size size) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, size);
      recorder.endRecording().dispose();
    }

    test('a function with an asymptote (tan) does not throw', () {
      final painter = GraphPainter(
        function: TanExpr(_x),
        xMin: -2,
        xMax: 2, // spans tan's asymptote at pi/2
        axisColor: const Color(0xFF000000),
        gridColor: const Color(0xFF000000),
        curveColor: const Color(0xFF000000),
      );
      expect(() => paintTo(painter, const Size(400, 300)), returnsNormally);
    });

    test('a zero-size canvas does not throw', () {
      final painter = GraphPainter(
        function: SinExpr(_x),
        xMin: -1,
        xMax: 1,
        axisColor: const Color(0xFF000000),
        gridColor: const Color(0xFF000000),
        curveColor: const Color(0xFF000000),
      );
      expect(() => paintTo(painter, Size.zero), returnsNormally);
    });

    test('a constant function (flat line, yMin == yMax) does not throw', () {
      final painter = GraphPainter(
        function: const ConstExpr(5),
        xMin: -10,
        xMax: 10,
        axisColor: const Color(0xFF000000),
        gridColor: const Color(0xFF000000),
        curveColor: const Color(0xFF000000),
      );
      expect(() => paintTo(painter, const Size(400, 300)), returnsNormally);
    });
  });
}
