import 'package:flutter/material.dart';

class Responsive {
  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;
  static bool isMobile(BuildContext context) => getScreenWidth(context) < 600;
  static bool isTablet(BuildContext context) =>
      getScreenWidth(context) >= 600 && getScreenWidth(context) < 900;
  static bool isDesktop(BuildContext context) => getScreenWidth(context) >= 900;

  static int getGridColumns(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < 600) return 1;
    if (width < 900) return 2;
    return 3;
  }

  static EdgeInsets adaptivePadding(BuildContext context, {double base = 16}) {
    final scale = getScreenWidth(context) / 360;
    final scaled = base * (scale < 0.8 ? 0.8 : (scale > 1.5 ? 1.5 : scale));
    return EdgeInsets.all(scaled);
  }

  static double responsiveFontSize(BuildContext context, {double base = 16}) {
    final scale = getScreenWidth(context) / 360;
    return base * (scale < 0.9 ? 0.9 : (scale > 1.3 ? 1.3 : scale));
  }
}
