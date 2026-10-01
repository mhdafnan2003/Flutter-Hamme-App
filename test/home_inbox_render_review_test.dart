import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hamme_app/features/home/presentation/screens/home_screen.dart';
import 'package:hamme_app/features/home/presentation/screens/share_playing_screen.dart';
import 'package:hamme_app/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:hamme_app/features/inbox/presentation/widgets/inbox_share_export_widget.dart';
import 'package:hamme_app/features/inbox/domain/models/inbox_variation.dart';
import 'package:hamme_app/features/shared/presentation/widgets/hamme_bottom_nav_bar.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/providers/onboarding_providers.dart';
import 'package:hamme_app/utils/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'safety_test_fakes.dart';

class _SignedOut extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

void main() {
  testWidgets('render Home Inbox and story canvases with real fonts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_name': 'Sofia',
      'onboarding_username': 'soooofiayy',
    });
    dotenv.loadFromString(
      envString: 'SHARE_LINK_BASE=https://example.test/poll',
    );
    await tester.runAsync(() async {
      for (final family in ['Nunito', 'Schibsted Grotesk']) {
        await (FontLoader(family)..addFont(
          rootBundle.load(
            'assets/fonts/${family.replaceAll(' ', '')}-VariableFont_wght.ttf',
          ),
        )).load();
      }
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      )).load();
    });
    final oldShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = oldShadows);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const variation = InboxVariation(
      gradientColors: [Color(0xFFCE58E6), Color(0xFFFE3B9D)],
      borderColor: Color(0xFFFF3C9E),
      emoji: '😍',
      typeKey: 'crush',
      tagline: 'Main character energy',
    );
    final cases = <(String, Size, Widget, bool)>[
      ('home-393', const Size(393, 852), const HomeScreen(), true),
      ('home-320', const Size(320, 568), const HomeScreen(), true),
      ('inbox-empty-393', const Size(393, 852), const InboxScreen(), true),
      ('inbox-filled-393', const Size(393, 852), const InboxScreen(), true),
      ('inbox-filled-320', const Size(320, 568), const InboxScreen(), true),
      (
        'inbox-export-393',
        const Size(393, 852),
        const InboxShareExportWidget(variation: variation, count: 156),
        false,
      ),
      (
        'inbox-export-1080',
        const Size(1080, 1920),
        const InboxShareExportWidget(variation: variation, count: 156),
        false,
      ),
      (
        'story-instagram-1080',
        const Size(1080, 1920),
        const StoryExportWidget(draft: OnboardingDraft()),
        false,
      ),
      (
        'story-snapchat-1080',
        const Size(1080, 1920),
        const StoryExportWidget(draft: OnboardingDraft(), showBrandLink: true),
        false,
      ),
    ];
    for (final (name, size, screen, withNav) in cases) {
      tester.view.physicalSize = size;
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(name),
          overrides: [
            authControllerProvider.overrideWith(_SignedOut.new),
            visibleInboxInteractionsProvider.overrideWith(
              (ref) => AsyncData(
                name.contains('filled')
                    ? [testVote('anonymous', anonymous: true)]
                    : [],
              ),
            ),
          ],
          child: MaterialApp(
            theme: TAppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding:
                    withNav
                        ? const EdgeInsets.only(top: 59, bottom: 34)
                        : EdgeInsets.zero,
                viewPadding:
                    withNav
                        ? const EdgeInsets.only(top: 59, bottom: 34)
                        : EdgeInsets.zero,
              ),
              child: RepaintBoundary(
                key: key,
                child: Scaffold(
                  body: screen,
                  bottomNavigationBar:
                      withNav
                          ? HammeBottomNavBar(
                            currentIndex: name.startsWith('home') ? 0 : 2,
                            onTap: (_) {},
                          )
                          : null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(image.image, key.currentContext!);
        }
        for (final path in [
          'assets/icons/emoji_crush.png',
          'assets/icons/emoji_friend.png',
          'assets/icons/emoji_frenemy.png',
          'assets/icons/emoji_monkey.png',
          'assets/icons/copy.png',
          'assets/images/placelink.png',
        ]) {
          await precacheImage(AssetImage(path), key.currentContext!);
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      if (Platform.environment['RENDER_UI'] == '1') {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory(
            '${Directory.systemTemp.path}/hamme-ui-review',
          );
          await directory.create(recursive: true);
          await File(
            '${directory.path}/app-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    debugDisableShadows = oldShadows;
  });
}
