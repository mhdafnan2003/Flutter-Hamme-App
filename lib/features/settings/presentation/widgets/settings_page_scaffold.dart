import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/fonts.dart';

class SettingsPageScaffold extends StatelessWidget {
  const SettingsPageScaffold({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: IconButton(
            onPressed: () => context.pop(),
            style: IconButton.styleFrom(
              backgroundColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2E)
                      : TColors.hammeSurface,
            ),
            icon: const Icon(CupertinoIcons.left_chevron, size: 20),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: TFonts.nunito,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, color: TColors.darkGrey, size: 25),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: TColors.darkGrey,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: dark ? const Color(0xFF242428) : TColors.hammeSurface,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      minTileHeight: 82,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF34343A)
                  : const Color(0xFFE5E7EB),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: TFonts.nunito,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
      subtitle:
          subtitle == null
              ? null
              : Text(
                subtitle!,
                style: const TextStyle(
                  fontFamily: TFonts.nunito,
                  fontWeight: FontWeight.w600,
                ),
              ),
      trailing:
          trailing ??
          const Icon(
            CupertinoIcons.chevron_right,
            color: TColors.darkGrey,
            size: 22,
          ),
    );
  }
}
