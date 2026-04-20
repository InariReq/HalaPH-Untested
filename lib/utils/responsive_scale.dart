import 'package:flutter/material.dart';

class ResponsiveScale {
  static double of(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    const baseWidth = 390.0;
    const minScale = 0.85;
    const maxScale = 1.15;
    return (width / baseWidth).clamp(minScale, maxScale);
  }

  static EdgeInsets padding(BuildContext context,
      {double horizontal = 20, double vertical = 16}) {
    final scale = of(context);
    return EdgeInsets.symmetric(
        horizontal: horizontal * scale, vertical: vertical * scale);
  }

  static double spacing(BuildContext context, double value) {
    return of(context) * value;
  }
}
