import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/community_rules_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/dob_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/name_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/profile_upload_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/pro_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/social_media_screen.dart';
import 'package:hamme_app/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/billing_providers.dart';
import 'package:hamme_app/utils/theme/theme.dart';
import 'package:hamme_app/utils/constants/image_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOut extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

class _Billing extends BillingController {
  @override
  BillingState build() => const BillingState();
}

void main() {
  setUpAll(() async {
    for (final font in ['Nunito', 'Schibsted Grotesk']) {
      final loader = FontLoader(font)..addFont(
        rootBundle.load(
          'assets/fonts/${font.replaceAll(' ', '')}-VariableFont_wght.ttf',
        ),
      );
      await loader.load();
    }
  });

  testWidgets('render onboarding with actual fonts and device safe areas', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final screens = <String, Widget>{
      'splash': const SplashScreen(),
      'dob': const DobScreen(),
      'name': const NameScreen(),
      'photo': const ProfileUploadScreen(),
      'social': const SocialMediaScreen(),
      'pro': const ProScreen(),
      'community': const CommunityRulesScreen(),
    };
    for (final entry in screens.entries) {
      final keyboard = ['name', 'social'].contains(entry.key);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(entry.key),
          overrides: [
            authControllerProvider.overrideWith(_SignedOut.new),
            billingControllerProvider.overrideWith(_Billing.new),
          ],
          child: MaterialApp(
            theme: TAppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(393, 852),
                padding: EdgeInsets.only(top: 59, bottom: keyboard ? 0 : 34),
                viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
                viewInsets: EdgeInsets.only(bottom: keyboard ? 343 : 0),
              ),
              child: RepaintBoundary(key: boundaryKey, child: entry.value),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(Scaffold));
        for (final path in [
          TImages.emojiBirthday,
          TImages.emojiSpeaking,
          TImages.emojiCamera,
          TImages.proHammeLogo,
          TImages.proUnlocked,
          TImages.proInfinity,
          TImages.proRewind,
          TImages.proHighVoltage,
        ]) {
          await precacheImage(AssetImage(path), context);
        }
      });
      await tester.pump(const Duration(milliseconds: 1800));
      expect(tester.takeException(), isNull, reason: entry.key);
      switch (entry.key) {
        case 'dob':
          expect(
            tester.getRect(find.text('What’s your age?')).top,
            closeTo(130, 1),
          );
          expect(tester.getRect(find.text('years old')).top, closeTo(348, 1));
          expect(tester.getRect(find.text('Next')).center.dy, closeTo(763, 1));
          break;
        case 'name':
          expect(
            tester.getRect(find.text('What’s your name?')).top,
            closeTo(130, 1),
          );
          expect(tester.getRect(find.byType(TextField)).top, closeTo(285, 1));
          expect(
            tester.getRect(find.text('you cannot change this later')).top,
            closeTo(398, 1),
          );
          break;
        case 'photo':
          expect(
            tester.getRect(find.text('Set your profile pic')).top,
            closeTo(130, 1),
          );
          expect(tester.getRect(find.text('Next')).center.dy, closeTo(763, 1));
          break;
        case 'pro':
          // Keep the additional social-proof row from frame 4744:4263.
          expect(
            tester.getRect(find.text('Unlock Unlimited')).top,
            closeTo(196, 1),
          );
          expect(
            tester.getRect(find.text('Unlimited Play')).top,
            closeTo(328, 1),
          );
          expect(
            tester.getRect(find.text('Unlimited Rewinds')).top,
            closeTo(428, 1),
          );
          expect(
            tester.getRect(find.text('Priority Profile')).top,
            closeTo(526, 1),
          );
          expect(
            tester.getRect(find.byType(ElevatedButton)).top,
            closeTo(690, 1),
          );
          expect(tester.getRect(find.text('Privacy')).top, closeTo(804, 1));
          expect(tester.getRect(find.text('Terms')).top, closeTo(804, 1));
          break;
      }
      if (Platform.environment['RENDER_UI'] == '1') {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('${Directory.systemTemp.path}/hamme-ui-review');
          await dir.create(recursive: true);
          await File(
            '${dir.path}/app-onboarding-${entry.key}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
