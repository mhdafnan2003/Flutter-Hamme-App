import 'package:flutter/material.dart';

class ShareInstructionPreview extends StatelessWidget {
  const ShareInstructionPreview({
    super.key,
    required this.imagePath,
  });

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: SizedBox(
        width: double.infinity,
        height: 200,
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          alignment: Alignment.topCenter,
        ),
      ),
    );
  }
}
