class ShareInstructionData {
  const ShareInstructionData({
    required this.prefix,
    required this.highlight,
    required this.suffix,
    required this.imagePath,
  });

  final String prefix;
  final String highlight;
  final String suffix;
  final String imagePath;

  static ShareInstructionData forStep(int step, {required bool isInstagram}) {
    if (isInstagram) {
      return switch (step) {
        1 => const ShareInstructionData(
          prefix: 'Click the ',
          highlight: 'sticker',
          suffix: ' button',
          imagePath: 'assets/images/share/ig_step_1.png',
        ),
        2 => const ShareInstructionData(
          prefix: 'Click the ',
          highlight: 'LINK',
          suffix: ' button',
          imagePath: 'assets/images/share/ig_step_2.png',
        ),
        3 => const ShareInstructionData(
          prefix: 'Paste your Link!',
          highlight: '',
          suffix: '',
          imagePath: 'assets/images/share/ig_step_3.png',
        ),
        _ => const ShareInstructionData(
          prefix: 'Frame the Link!',
          highlight: '',
          suffix: '',
          imagePath: 'assets/images/share/ig_step_4.png',
        ),
      };
    }

    return switch (step) {
      1 => const ShareInstructionData(
        prefix: 'Take a Photo',
        highlight: '',
        suffix: '',
        imagePath: 'assets/images/share/snap_step_1.png',
      ),
      2 => const ShareInstructionData(
        prefix: 'Click the ',
        highlight: 'LINK-SNAP',
        suffix: ' button',
        imagePath: 'assets/images/share/snap_step_2.png',
      ),
      3 => const ShareInstructionData(
        prefix: 'Paste your Link!',
        highlight: '',
        suffix: '',
        imagePath: 'assets/images/share/snap_step_3.png',
      ),
      _ => const ShareInstructionData(
        prefix: 'Click “Attach to Snap”',
        highlight: '',
        suffix: '',
        imagePath: 'assets/images/share/snap_step_4.png',
      ),
    };
  }
}
