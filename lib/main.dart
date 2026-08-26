import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/calculator_controller.dart';
import 'ui/calculator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(RpnEdgeApp(controller: CalculatorController(prefs)));
}

class RpnEdgeApp extends StatelessWidget {
  const RpnEdgeApp({super.key, required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final t = controller.theme;
        return MaterialApp(
          title: 'Stackline',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: t.brightness,
            scaffoldBackgroundColor: t.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: t.accent,
              brightness: t.brightness,
            ),
          ),
          home: CalculatorScreen(controller: controller),
        );
      },
    );
  }
}
