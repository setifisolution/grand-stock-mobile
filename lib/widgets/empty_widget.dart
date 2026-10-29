import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'subtitle_text.dart';
import 'title_text.dart';


class EmptyWidget extends StatelessWidget {
  final String imagePath, title, subtitle;

  const EmptyWidget({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (imagePath.endsWith('.svg'))
              SvgPicture.asset(
                imagePath,
                height: size.height * 0.35,
                width: double.infinity,
              )
            else
              Image.asset(
                imagePath,
                height: size.height * 0.35,
                width: double.infinity,
              ),
            const TitlesTextWidget(
              label: "Whoops",
              fontSize: 40,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            SubtitleTextWidget(
              label: title,
              fontWeight: FontWeight.w600,
              fontSize: 25,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SubtitleTextWidget(
                label: subtitle,
                fontWeight: FontWeight.w400,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}