import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/safety_providers.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/fonts.dart';
import '../../../settings/presentation/widgets/settings_page_scaffold.dart';
import '../../domain/models/blocked_users.dart';
import '../safety_error_message.dart';

/// People and anonymous voters the user blocked, with a way to unblock them.
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  // Unblocked during this visit. Dropped from the list straight away instead
  // of waiting for the refetch.
  final Set<String> _unblockedIds = {};
  final Set<String> _busyIds = {};
  bool _anonymousCleared = false;
  bool _clearingAnonymous = false;

  Future<void> _unblock(BlockedUser user) async {
    final confirmed = await _confirm(
      title: 'Unblock ${user.displayName}?',
      message: "They'll be able to vote for you and match with you again.",
      action: 'Unblock',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyIds.add(user.id));
    try {
      await ref.read(safetyControllerProvider.notifier).unblockUser(user.id);
      if (!mounted) return;
      setState(() => _unblockedIds.add(user.id));
      _showSnackBar('${user.displayName} is unblocked.');
    } catch (error) {
      if (mounted) {
        await _showError("Couldn't unblock ${user.displayName}", error);
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(user.id));
    }
  }

  Future<void> _unblockAnonymous() async {
    final confirmed = await _confirm(
      title: 'Unblock all anonymous voters?',
      message:
          "They'll be able to vote for you again. Votes you reported stay "
          'removed.',
      action: 'Unblock all',
    );
    if (!confirmed || !mounted) return;

    setState(() => _clearingAnonymous = true);
    try {
      await ref.read(safetyControllerProvider.notifier).clearAnonymousBlocks();
      if (!mounted) return;
      setState(() => _anonymousCleared = true);
      _showSnackBar('Anonymous voters unblocked.');
    } catch (error) {
      if (mounted) {
        await _showError("Couldn't unblock anonymous voters", error);
      }
    } finally {
      if (mounted) setState(() => _clearingAnonymous = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(message),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(action),
              ),
            ],
          ),
    );
    return confirmed == true;
  }

  Future<void> _showError(String title, Object error) {
    return showCupertinoDialog<void>(
      context: context,
      builder:
          (dialogContext) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(safetyErrorMessage(error)),
            ),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    ref.invalidate(blockedUsersProvider);
    try {
      await ref.read(blockedUsersProvider.future);
    } catch (_) {
      // The error state below already shows the failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = ref.watch(blockedUsersProvider);

    return SettingsPageScaffold(
      title: 'Blocked users',
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: blocked.when(
          data: _buildContent,
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error:
              (error, _) => _MessageView(
                icon: CupertinoIcons.wifi_exclamationmark,
                title: "Couldn't load blocked users",
                message: safetyErrorMessage(error),
                actionLabel: 'Try again',
                onAction: () => ref.invalidate(blockedUsersProvider),
              ),
        ),
      ),
    );
  }

  Widget _buildContent(BlockedUsersResult result) {
    final users =
        result.users.where((user) => !_unblockedIds.contains(user.id)).toList();
    final anonymousCount = _anonymousCleared ? 0 : result.anonymousBlockedCount;
    if (users.isEmpty && anonymousCount <= 0) {
      return const _MessageView(
        icon: CupertinoIcons.hand_raised_fill,
        title: 'No one is blocked',
        message:
            "When you block someone from a vote or a match, they'll show up "
            'here.',
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 24),
          child: Text(
            "Blocked people can't vote for you or match with you, and you "
            "won't see their votes.",
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: TColors.darkGrey,
            ),
          ),
        ),
        if (users.isNotEmpty)
          _Section(
            title: 'People',
            children: [
              for (final user in users)
                _BlockedUserTile(
                  user: user,
                  busy: _busyIds.contains(user.id),
                  onUnblock: () => _unblock(user),
                ),
            ],
          ),
        if (users.isNotEmpty && anonymousCount > 0) const SizedBox(height: 28),
        if (anonymousCount > 0)
          _Section(
            title: 'Anonymous voters',
            children: [
              _AnonymousVotersTile(
                count: anonymousCount,
                busy: _clearingAnonymous,
                onUnblockAll: _unblockAnonymous,
              ),
            ],
          ),
      ],
    );
  }
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _sectionColor(BuildContext context) =>
    _isDark(context) ? const Color(0xFF242428) : TColors.hammeSurface;

Color _avatarColor(BuildContext context) =>
    _isDark(context) ? const Color(0xFF34343A) : const Color(0xFFE5E7EB);

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: TFonts.nunito,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: TColors.darkGrey,
            ),
          ),
        ),
        Material(
          color: _sectionColor(context),
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 18, endIndent: 18),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.busy,
    required this.onUnblock,
  });

  final BlockedUser user;
  final bool busy;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final username = user.username;
    return _TileLayout(
      leading: _UserAvatar(
        imageUrl: user.avatarUrl,
        fallbackText: user.displayName,
      ),
      title: user.displayName,
      subtitle: username != null && user.name.isNotEmpty ? '@$username' : null,
      trailing:
          busy
              ? const _BusyIndicator()
              : _PillButton(label: 'Unblock', onPressed: onUnblock),
    );
  }
}

class _AnonymousVotersTile extends StatelessWidget {
  const _AnonymousVotersTile({
    required this.count,
    required this.busy,
    required this.onUnblockAll,
  });

  final int count;
  final bool busy;
  final VoidCallback onUnblockAll;

  @override
  Widget build(BuildContext context) {
    return _TileLayout(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _avatarColor(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: const Icon(
            CupertinoIcons.person_fill,
            size: 34,
            color: Color(0xFFB8B8B8),
          ),
        ),
      ),
      title: '$count anonymous ${count == 1 ? 'voter' : 'voters'} blocked',
      subtitle: "They can't vote for you.",
      trailing:
          busy
              ? const _BusyIndicator()
              : _PillButton(label: 'Unblock all', onPressed: onUnblockAll),
    );
  }
}

class _TileLayout extends StatelessWidget {
  const _TileLayout({
    required this.leading,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: TFonts.nunito,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: TFonts.nunito,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: TColors.darkGrey,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.imageUrl, required this.fallbackText});

  final String? imageUrl;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final initial =
        fallbackText.replaceFirst('@', '').characters.firstOrNull ?? '?';
    final fallback = Center(
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          fontFamily: TFonts.nunito,
          fontWeight: FontWeight.w900,
          fontSize: 20,
          color: TColors.darkGrey,
        ),
      ),
    );
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _avatarColor(context),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          url != null && url.startsWith('http')
              ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              )
              : fallback,
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onPressed,
    this.onPageBackground = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// Sits on the page rather than on a grey section, so it needs a fill.
  final bool onPageBackground;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final background =
        dark
            ? const Color(0xFF34343A)
            : onPageBackground
            ? TColors.hammeSurface
            : Colors.white;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: dark ? Colors.white : Colors.black,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: TFonts.nunito,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _BusyIndicator extends StatelessWidget {
  const _BusyIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 44,
      height: 44,
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}

/// Full-page message for the empty and error states. Scrollable so
/// pull-to-refresh still works.
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 40),
      children: [
        Icon(icon, size: 52, color: TColors.darkGrey),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: TFonts.nunito,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: TFonts.nunito,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: TColors.darkGrey,
          ),
        ),
        if (label != null && action != null) ...[
          const SizedBox(height: 24),
          Center(
            child: _PillButton(
              label: label,
              onPressed: action,
              onPageBackground: true,
            ),
          ),
        ],
      ],
    );
  }
}
