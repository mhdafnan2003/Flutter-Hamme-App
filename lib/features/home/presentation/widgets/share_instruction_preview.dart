import 'dart:math' as math;

import 'package:flutter/material.dart';

class ShareInstructionPreview extends StatelessWidget {
  const ShareInstructionPreview({super.key, required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(281.0, constraints.maxWidth);
        return Center(
          child: SizedBox(
            width: width,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: AspectRatio(
                aspectRatio: 281 / 224,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
