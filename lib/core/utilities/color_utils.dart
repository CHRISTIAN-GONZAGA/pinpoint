import 'package:flutter/material.dart';

/// Parses hex color strings from API into Flutter [Color].
Color colorFromHex(String hex) {
  final buffer = StringBuffer();
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) buffer.write('ff');
  buffer.write(value);
  return Color(int.parse(buffer.toString(), radix: 16));
}
