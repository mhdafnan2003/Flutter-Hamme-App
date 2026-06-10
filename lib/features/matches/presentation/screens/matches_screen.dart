import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:url_launcher/url_launcher.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F2F7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.left_chevron,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Image.asset(TImages.hammeHomeLogo, height: 32),
                    ),
                  ),
                  const SizedBox(width: 44), // Spacer to balance back button
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Match List ────────────────────────────────────────────────
            Expanded(
              child: matches.when(
                data: (items) {
                  if (items.isEmpty) return const _EmptyMatchesView();
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final match = items[index];
                      return _MatchTile(match: match);
                    },
                  );
                },
                loading: () => const Center(
                  child: CupertinoActivityIndicator(),
                ),
                error: (error, _) => Center(
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(fontFamily: TFonts.nunito),
                  ),
                ),
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.only(bottom: 24, top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🚨 ', style: TextStyle(fontSize: 14)),
                  Text(
                    'Matches are vanished after 24hrs',
                    style: TextStyle(
                      fontFamily: TFonts.nunito,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match});
  final MatchRecord match;

  Future<void> _openSocial() async {
    final user = match.matchedUser;
    final handle = (user.instagramId.isNotEmpty ? user.instagramId : user.shareCode).replaceAll('@', '');
    if (handle.isEmpty) return;

    final isSnap = user.email.contains('snap') || 
                   user.name.toLowerCase().contains('snap') ||
                   user.id.contains('snap');
    
    final Uri url;
    if (isSnap) {
      url = Uri.parse('snapchat://add/$handle');
    } else {
      url = Uri.parse('instagram://user?username=$handle');
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = isSnap 
            ? Uri.parse('https://www.snapchat.com/add/$handle')
            : Uri.parse('https://www.instagram.com/$handle/');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = match.matchedUser;
    final name = user.name.trim().isNotEmpty ? user.name.trim() : 'Someone';
    final handle = user.instagramId.isNotEmpty ? user.instagramId : '@${user.shareCode}';
    
    final isSnap = handle.toLowerCase().contains('snap') || 
                   user.id.contains('snap');
    final platformLabel = isSnap ? 'snap' : 'ig';

    return GestureDetector(
      onTap: _openSocial,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE5E5EA),
            ),
            clipBehavior: Clip.antiAlias,
            child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                ? Image.network(user.avatarUrl!, fit: BoxFit.cover)
                : Center(
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: TFonts.nunito,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),

          // Name & Social
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '$platformLabel: $handle',
                  style: const TextStyle(
                    fontFamily: TFonts.nunito,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Close button
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.xmark,
              color: Colors.black54,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMatchesView extends StatelessWidget {
  const _EmptyMatchesView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🥺', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'No matches yet',
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: TColors.hammePrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep playing to find yours!',
            style: TextStyle(
              fontFamily: TFonts.nunito,
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
