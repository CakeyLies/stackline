import 'dart:math' as math;

import 'package:decimal/decimal.dart';

import 'engine.dart';

String formatDecimal(Decimal value, DisplayMode mode, int digits) {
  switch (mode) {
    case DisplayMode.fix:
      return _formatFix(value, digits);
    case DisplayMode.sci:
      return _formatSci(value, digits);
    case DisplayMode.eng:
      return _formatEng(value, digits);
  }
}

String _formatFix(Decimal value, int digits) {
  if (value.abs() >= Decimal.parse('1e15')) {
    return _formatSci(value, digits);
  }
  return value.toStringAsFixed(digits);
}

String _formatSci(Decimal value, int digits) {
  final fraction = digits <= 0 ? 0 : digits - 1;
  final s = value.toStringAsExponential(fraction);
  return _normalizeExponent(s);
}

String _formatEng(Decimal value, int digits) {
  if (value == Decimal.zero) {
    final fraction = digits <= 0 ? 0 : digits - 1;
    final zeros = fraction > 0 ? '.${'0' * fraction}' : '';
    return '0${zeros}e0';
  }
  final d = value.toDouble();
  final exp3 = (math.log(d.abs()) / math.ln10).floor() ~/ 3 * 3;
  final mantissa = d / math.pow(10, exp3);
  final fraction = digits <= 0 ? 0 : digits - 1;
  return '${mantissa.toStringAsFixed(fraction)}e$exp3';
}

String _normalizeExponent(String s) {
  final match = RegExp(r'^([^e]+)e([+-])(\d+)$').firstMatch(s);
  if (match == null) return s;
  final mantissa = match.group(1)!;
  final sign = match.group(2)!;
  final digits = match.group(3) ?? '0';
  final exp = sign == '-' ? '-$digits' : digits;
  return '${mantissa}e$exp';
}
