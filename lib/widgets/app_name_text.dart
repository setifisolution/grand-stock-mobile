import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'title_text.dart';

class AppNameTextWidget extends StatelessWidget {
  final double? fontSize ;
  final String? text;

  const AppNameTextWidget({super.key,this.fontSize, this.text});
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      period: const Duration(seconds: 16),
      baseColor: Colors.green,
      highlightColor: Colors.red,
      child:  TitlesTextWidget(
        label:  text ?? "SETIFIS MED",
        fontSize: fontSize ??  30,
      ),
    );
  }
}
