import 'package:flutter/material.dart';

class TColors {
  // App theme colors
  static const Color primary = Color(0xFF4b68ff);
  static const Color secondary = Color(0xFFFFE24B);
  static const Color accent = Color(0xFFb0c7ff);

  // Text colors
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textWhite = Colors.white;

  // Background colors
  static const Color light = Color(0xFFF6F6F6);
  static const Color dark = Color(0xFF272727);
  static const Color primaryBackground = Color(0xFFF3F5FF);

  // Background Container colors
  static const Color lightContainer = Color(0xFFF6F6F6);
  static Color darkContainer = TColors.white.withValues(alpha: 0.1);

  // Button colors
  static const Color buttonPrimary = Color(0xFF4b68ff);
  static const Color buttonSecondary = Color(0xFF6C757D);
  static const Color buttonDisabled = Color(0xFFC4C4C4);

  // Border colors
  static const Color borderPrimary = Color(0xFFD9D9D9);
  static const Color borderSecondary = Color(0xFFE6E6E6);

  // Error and validation colors
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF1976D2);

  // Neutral Shades
  static const Color black = Color(0xFF232323);
  static const Color darkerGrey = Color(0xFF4F4F4F);
  static const Color darkGrey = Color(0xFF939393);
  static const Color grey = Color(0xFFE0E0E0);
  static const Color softGrey = Color(0xFFF4F4F4);
  static const Color lightGrey = Color(0xFFF9F9F9);
  static const Color white = Color(0xFFFFFFFF);

  // Hamme UI colors
  static const Color hammePrimary = Color(0xFF9F6FFF);
  static const Color hammePrimaryDark = Color(0xFF7838FE);
  static const Color hammeTrack = Color(0xFFECEDED);
  static const Color hammeSurface = Color(0xFFF1F2F6);
  static const Color hammeMutedText = Color(0xFF8F8F8F);
  static const Color hammeInactiveText = Color(0xFF79797B);
  static const Color hammeAccentBlue = Color(0xFF4A85F6);

  // Instagram brand gradient (home profile badge)
  static const Color instagramGradient1 = Color(0xFF833AB4);
  static const Color instagramGradient2 = Color(0xFFFD1D1D);
  static const Color instagramGradient3 = Color(0xFFF56040);
  static const List<Color> instagramGradient = <Color>[
    instagramGradient1,
    instagramGradient2,
    instagramGradient3,
  ];

  // Snapchat brand color
  static const Color snapchatYellow = Color(0xFFFFFC00);

  // Inbox reaction card palette — Pink
  static const Color hammeInboxPinkStart = Color(0xFFCE58E6);
  static const Color hammeInboxPinkEnd = Color(0xFFFE3B9D);
  static const Color hammeInboxPinkBorder = Color(0xFFFF3C9E);

  // Inbox reaction card palette — Blue
  static const Color hammeInboxBlueStart = Color(0xFF01CAFD);
  static const Color hammeInboxBlueEnd = Color(0xFF0162FA);
  static const Color hammeInboxBlueBorder = Color(0xFF005FFC);
  static const Color hammePurpleColor = Color(0xFF925CFF);
  static const Color hammepinkcolor = Color(0xFFFF22F0);

  // Inbox reaction card palette — Purple
  static const Color hammeInboxPurpleStart = Color(0xFFB3A8E8);
  static const Color hammeInboxPurpleEnd = Color(0xFF535590);
  static const Color hammeInboxPurpleBorder = Color(0xFF535B97);

  // Play empty-state stacked card shade
  static const Color hammeCardShade = Color(0xDBF0F0F0);
}
