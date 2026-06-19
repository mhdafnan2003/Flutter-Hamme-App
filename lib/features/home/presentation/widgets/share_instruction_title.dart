import 'package:flutter/material.dart';
import 'package:hamme_app/features/home/domain/models/share_instruction_data.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class ShareInstructionTitle extends StatelessWidget {
  const ShareInstructionTitle({super.key, required this.data});

  final ShareInstructionData data;

  @override
  Widget build(BuildContext context) {
    if (data.highlight.isEmpty) {
      return Text(
        data.prefix,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: TFonts.nunito,
          fontWeight: FontWeight.w800,
          fontSize: 24,
          color: Colors.black,
        ),
      );
    }

    if (data.highlight == 'LINK') {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(data.prefix, style: _titleStyle),
          Image.asset(
            'assets/icons/link-insta.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          Text(data.suffix, style: _titleStyle),
        ],
      );
    }

    if (data.highlight == 'LINK-SNAP') {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(data.prefix, style: _titleStyle),
          Image.asset(
            'assets/icons/icon_line/paperclip.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          Text(data.suffix, style: _titleStyle),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(data.prefix, style: _titleStyle),
        Image.asset(
          'assets/icons/sticker.png',
          width: 34,
          height: 34,
          fit: BoxFit.contain,
        ),
        Text(data.suffix, style: _titleStyle),
      ],
    );
  }

  static const _titleStyle = TextStyle(
    fontFamily: TFonts.nunito,
    fontWeight: FontWeight.w800,
    fontSize: 18,
    color: Colors.black,
  );
}
