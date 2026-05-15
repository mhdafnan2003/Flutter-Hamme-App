class ShareInstructionData {
  const ShareInstructionData({
    required this.prefix,
    required this.highlight,
    required this.suffix,
  });

  final String prefix;
  final String highlight;
  final String suffix;

  static ShareInstructionData forStep(int step, {required bool isInstagram}) {
    if (isInstagram) {
      return switch (step) {
        1 => const ShareInstructionData(
          prefix: 'Click the ',
          highlight: 'sticker',
          suffix: ' button',
        ),
        2 => const ShareInstructionData(
          prefix: 'Click the ',
          highlight: 'LINK',
          suffix: ' button',
        ),
        3 => const ShareInstructionData(
          prefix: 'Paste your Link!',
          highlight: '',
          suffix: '',
        ),
        _ => const ShareInstructionData(
          prefix: 'Frame the Link!',
          highlight: '',
          suffix: '',
        ),
      };
    } else {
      // Snapchat steps
      return switch (step) {
        1 => const ShareInstructionData(
          prefix: 'Take a Photo',
          highlight: '',
          suffix: '',
        ),
        2 => const ShareInstructionData(
          prefix: 'Click the ',
          highlight: 'LINK-SNAP',
          suffix: ' button',
        ),
        3 => const ShareInstructionData(
          prefix: 'Paste your Link!',
          highlight: '',
          suffix: '',
        ),
        _ => const ShareInstructionData(
          prefix: 'Click "Attach to Snap"',
          highlight: '',
          suffix: '',
        ),
      };
    }
  }
}
