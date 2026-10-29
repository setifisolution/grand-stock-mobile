import 'package:flutter/material.dart';

import '../models/transfer_intern_model.dart';

class AppColors {
  static const Color lightScaffoldColor = Colors.white;
  static const Color lightPrimary = Color(0xFF181059);
  static const Color lightCardColor = Color.fromARGB(106, 250, 250, 250);
  static const Color darkScaffoldColor = Color.fromARGB(255, 9, 3, 27);
  static const Color darkPrimary = Color.fromARGB(255, 94, 75, 236);
  static List<Color> dashColor = [
    const Color(0xff1AB0B0),
    const Color(0xffFF7544),
    const Color(0xffFA5A7D),
    const Color(0xff8676FE),
  ];
  static const accent = Color(0xFF00B894);
  static const bg = Color(0xFFF6F8FB);
  static const ink = Color(0xFF2D3748);
  static const blue = Color(0xFF3B82F6);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFDC2626);
  static Color statusColor(String s) => switch (s) {
    TransferStatus.pending => amber,
    TransferStatus.sent => blue,
    TransferStatus.received => accent,
    TransferStatus.cancelled => red,
    _ => Colors.grey,
  };
}
