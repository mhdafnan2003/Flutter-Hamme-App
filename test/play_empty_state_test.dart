import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/play/presentation/screens/play_screen.dart';
import 'package:hamme_app/features/shared/presentation/widgets/hamme_bottom_nav_bar.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/models/play_limit_status.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/providers/play_limit_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOutAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

class _UnrestrictedLimit extends PlayLimitStatusNotifier {
  @override
  Future<PlayLimitStatus> build() async => PlayLimitStatus.unrestricted;
}

void main() {
  final renderKey = GlobalKey();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpEmptyPlay(WidgetTester tester, Size size) async {
    await tester.runAsync(() async {
      await (FontLoader('Nunito')..addFont(
        rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'),
      )).load();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutAuthController.new),
          playLimitStatusProvider.overrideWith(_UnrestrictedLimit.new),
          pendingPlayInteractionsProvider.overrideWith(
            (ref) => const AsyncData([]),
          ),
          visibleMatchesProvider.overrideWith((ref) => const AsyncData([])),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
                ),
                child: child!,
              ),
          home: RepaintBoundary(
            key: renderKey,
            child: Scaffold(
              body: const PlayScreen(),
              bottomNavigationBar: HammeBottomNavBar(
                currentIndex: 1,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('places the empty card at its Figma position', (tester) async {
    await pumpEmptyPlay(tester, const Size(393, 852));

    final card = tester.getRect(find.byKey(const Key('play-empty-front-card')));
    expect(card.left, 24);
    expect(card.width, 345);
    expect(card.height, 186);
    expect(card.top, closeTo(260, 2));
    expect(find.text('No one here yet'), findsOneWidget);
    expect(
      tester
          .getRect(
            find.text('Share your link to get reactions \nin your inbox!'),
          )
          .top,
      closeTo(486, 2),
    );
    expect(tester.takeException(), isNull);
    final back = tester.getRect(find.byKey(const Key('play-empty-back-card')));
    final middle = tester.getRect(
      find.byKey(const Key('play-empty-middle-card')),
    );
    expect(back.width, 226);
    expect(middle.width, 290);
    expect(card.top - back.top, closeTo(28, 0.001));
    expect(middle.top - back.top, closeTo(11.622, 0.001));
    if (Platform.environment['RENDER_UI'] == '1') {
      await tester.runAsync(() async {
        await (FontLoader('Nunito')..addFont(
          rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'),
        )).load();
        for (final widget in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(widget.image, renderKey.currentContext!);
        }
      });
      debugDisableShadows = false;
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            renderKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${Directory.systemTemp.path}/hamme-play-empty.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      debugDisableShadows = true;
    }
  });

  testWidgets('keeps the empty state visible on a shorter phone', (
    tester,
  ) async {
    await pumpEmptyPlay(tester, const Size(393, 740));

    final card = tester.getRect(find.byKey(const Key('play-empty-front-card')));
    final navTop = tester.getRect(find.byType(HammeBottomNavBar)).top;
    expect(card.bottom, lessThan(navTop));
    expect(find.text('No one here yet').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(852, 393),
    const Size(768, 1024),
  ]) {
    testWidgets('adapts empty state to $size', (tester) async {
      await pumpEmptyPlay(tester, size);
      final card = tester.getRect(
        find.byKey(const Key('play-empty-front-card')),
      );
      expect(card.width, lessThanOrEqualTo(345));
      expect(card.height / card.width, closeTo(186 / 345, 0.001));
      expect(card.center.dx, closeTo(size.width / 2, 0.001));
      expect(tester.takeException(), isNull);
    });
  }
}
