import 'package:flutter/material.dart';

class ShareInstructionPreview extends StatelessWidget {
  const ShareInstructionPreview({
    super.key,
    required this.step,
    required this.isInstagram,
  });

  final int step;
  final bool isInstagram;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Container(
        width: 240,
        height: 180,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF111111), Color(0xFF9A5B36), Color(0xFF52210E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: switch (step) {
          1 => Image.asset(
            'assets/images/share_link_button.png',
            fit: BoxFit.cover,
          ),
          2 => Image.asset(
            'assets/images/share_link_stickers.png',
            fit: BoxFit.cover,
          ),
          3 => Image.asset(
            'assets/images/share_paste_link.png',
            fit: BoxFit.cover,
          ),
          _ => Image.asset(
            'assets/images/share_frame_link.png',
            fit: BoxFit.cover,
          ),
        },
      ),
    );
  }
}
