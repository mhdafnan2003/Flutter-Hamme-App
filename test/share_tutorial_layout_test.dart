import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hamme_app/core/widgets/app_close_circle_button.dart';
import 'package:hamme_app/features/home/presentation/screens/share_preview_screen.dart';
import 'package:hamme_app/features/home/presentation/widgets/platform_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<GoRouter> pumpTutorial(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await (FontLoader('Nunito')..addFont(
        rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'),
      )).load();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      initialLocation: '/tutorial',
      routes: [
        GoRoute(
          path: '/tutorial',
          builder: (_, __) => const SharePreviewScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home reached')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: const EdgeInsets.only(top: 59, bottom: 34)),
                child: child!,
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('tutorial matches reference card and Close receives taps', (
    tester,
  ) async {
    await pumpTutorial(tester, const Size(393, 852));
    final card = tester.getRect(find.byKey(const Key('share-tutorial-card')));
    expect(card.left, 24);
    expect(card.width, 345);
    expect(card.top, closeTo(192, 2));
    expect(card.height, closeTo(551, 2));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(AppCloseCircleButton));
    await tester.pumpAndSettle();
    expect(find.text('Home reached'), findsOneWidget);
  });

  testWidgets('all platform steps remain reachable on a compact phone', (
    tester,
  ) async {
    await pumpTutorial(tester, const Size(320, 568));
    for (var platform = 0; platform < 2; platform++) {
      for (var step = 1; step < 4; step++) {
        await tester.ensureVisible(find.text('Next Step'));
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('Share'));
      expect(find.text('Share').hitTestable(), findsOneWidget);
      if (platform == 0) {
        await tester.ensureVisible(find.byType(PlatformPill).last);
        await tester.tap(find.byType(PlatformPill).last);
        await tester.pumpAndSettle();
        expect(find.text('Next Step'), findsOneWidget);
      }
    }
    await tester.tap(find.byType(AppCloseCircleButton));
    await tester.pumpAndSettle();
    expect(find.text('Home reached'), findsOneWidget);
  });
}
