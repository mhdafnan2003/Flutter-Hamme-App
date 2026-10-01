import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/widgets/app_close_circle_button.dart';
import 'package:hamme_app/features/interactions/domain/repositories/interaction_repository.dart';
import 'package:hamme_app/features/play/presentation/screens/play_screen.dart';
import 'package:hamme_app/features/matches/presentation/screens/matches_screen.dart';
import 'package:hamme_app/features/matches/presentation/screens/match_reply_screen.dart';
import 'package:hamme_app/models/match_record.dart';
import 'package:hamme_app/features/play/presentation/widgets/match_success_overlay.dart';
import 'package:hamme_app/features/shared/presentation/widgets/hamme_bottom_nav_bar.dart';
import 'package:hamme_app/models/interaction_result.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/models/play_limit_status.dart';
import 'package:hamme_app/models/vote_response.dart';
import 'package:hamme_app/providers/interaction_providers.dart';
import 'package:hamme_app/providers/play_limit_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'safety_test_fakes.dart';

class _UnrestrictedLimit extends PlayLimitStatusNotifier {
  @override
  Future<PlayLimitStatus> build() async => PlayLimitStatus.unrestricted;
}

class _CooldownLimit extends PlayLimitStatusNotifier {
  @override
  Future<PlayLimitStatus> build() async => PlayLimitStatus(
    limited: true,
    isPro: false,
    viewsLeft: 0,
    maxCards: 12,
    resetAt: DateTime.now().add(const Duration(minutes: 3)),
    cooldownMinutes: 3,
  );
}

class _PendingRepository implements InteractionRepository {
  final pending = Completer<VoteResponse>();
  @override
  Future<VoteResponse> respondToInteraction({
    String? targetUserId,
    String? interactionId,
    required InteractionType type,
  }) => pending.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen,
    Size size, {
    double scale = 1,
    bool queue = false,
    bool cooldown = false,
    List<MatchRecord> matches = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      )).load();
      await (FontLoader('Nunito')..addFont(
        rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'),
      )).load();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testSafetyOverrides(
            repository: FakeSafetyRepository(),
            matches: matches,
            votes:
                queue
                    ? [
                      testVote('v1', from: 'u1').copyWith(
                        fromUserName: 'Aneet padda',
                        fromUserUsername: 'anei.pey',
                      ),
                    ]
                    : [],
          ),
          playLimitStatusProvider.overrideWith(
            cooldown ? _CooldownLimit.new : _UnrestrictedLimit.new,
          ),
          interactionRepositoryProvider.overrideWithValue(_PendingRepository()),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
                ),
                child: RepaintBoundary(
                  key: const Key('visual-boundary'),
                  child: child!,
                ),
              ),
          home: screen,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('UI_SCREENSHOTS')) return;
    debugDisableShadows = false;
    final context = tester.element(find.byKey(const Key('visual-boundary')));
    await tester.runAsync(() async {
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, context);
      }
    });
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(
      tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('visual-boundary')),
      ),
    );
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('visual-boundary')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(
        '${Directory.systemTemp.path}/hamme-ui-review',
      )..createSync(recursive: true);
      File(
        '${directory.path}/app-$name.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
    debugDisableShadows = true;
  }

  for (final size in [
    const Size(393, 852),
    const Size(320, 640),
    const Size(320, 480),
  ]) {
    testWidgets(
      'non-match rewind and next profile fit at $size with actual Nunito',
      (tester) async {
        await pumpScreen(
          tester,
          Scaffold(
            body: const PlayScreen(),
            bottomNavigationBar: HammeBottomNavBar(
              currentIndex: 1,
              onTap: (_) {},
            ),
          ),
          size,
          queue: true,
        );
        expect(tester.takeException(), isNull);
        if (size.width == 393) {
          final card = tester.getRect(
            find.byKey(const Key('play-queue-front-card')),
          );
          expect(card.topLeft, const Offset(24, 260));
          expect(card.size, const Size(345, 187));
          expect(
            tester.getRect(find.byKey(const Key('play-queue-avatar'))).top,
            207,
          );
        }
        await screenshot(tester, 'queue-${size.width.toInt()}');
        await tester.ensureVisible(find.text('Friend'));
        await tester.tap(find.text('Friend'));
        await tester.pump();
        expect(find.text('Not a Match!'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await screenshot(
          tester,
          'nonmatch-${size.width.toInt()}-${size.height.toInt()}',
        );
        await tester.ensureVisible(find.text('See next profile'));
        expect(find.text('See next profile').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final size in [const Size(360, 852), const Size(320, 480)]) {
    testWidgets('success content and close remain usable at $size', (
      tester,
    ) async {
      var dismissed = false;
      final match = testNamedMatch('m1', userId: 'u1', name: 'Ava');
      await pumpScreen(
        tester,
        MatchSuccessOverlay(
          result: InteractionResult(
            interaction: testVote('v1', from: 'u1'),
            matched: true,
            match: match,
          ),
          currentUserImageUrl: null,
          onDismiss: () => dismissed = true,
        ),
        size,
      );
      expect(tester.takeException(), isNull);
      await screenshot(
        tester,
        'success-${size.width.toInt()}-${size.height.toInt()}',
      );
      expect(find.byType(AppCloseCircleButton).hitTestable(), findsOneWidget);
      await tester.tap(find.byType(AppCloseCircleButton));
      expect(dismissed, isTrue);
      await tester.ensureVisible(find.text('Try Another Profile'));
      expect(find.text('Try Another Profile').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final size in [const Size(393, 852), const Size(320, 480)]) {
    testWidgets('cooldown card and upgrade remain reachable at $size', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: const PlayScreen(),
          bottomNavigationBar: HammeBottomNavBar(
            currentIndex: 1,
            onTap: (_) {},
          ),
        ),
        size,
        cooldown: true,
      );
      expect(tester.takeException(), isNull);
      await screenshot(tester, 'cooldown-${size.width.toInt()}');
      await tester.ensureVisible(find.text('Play Now'));
      expect(find.text('Play Now').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('matches empty and populated render with actual fonts', (
    tester,
  ) async {
    await pumpScreen(tester, const MatchesScreen(), const Size(393, 852));
    await screenshot(tester, 'matches-empty');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await pumpScreen(
      tester,
      const MatchesScreen(),
      const Size(393, 852),
      matches: [
        testNamedMatch('m1', userId: 'u1', name: 'Christina'),
        testAnonymousMatch('a1'),
      ],
    );
    await screenshot(tester, 'matches-populated');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reply renders with actual fonts and images', (tester) async {
    await pumpScreen(
      tester,
      MatchReplyScreen(
        match: testNamedMatch('m1', userId: 'u1', name: 'Ava'),
        currentUserImageUrl: null,
      ),
      const Size(393, 852),
    );
    await screenshot(tester, 'reply-393');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('large text preserves play voting and result controls', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const PlayScreen(),
      const Size(320, 480),
      scale: 1.5,
      queue: true,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Friend'));
    await tester.tap(find.text('Friend'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('See next profile'));
    expect(find.text('See next profile').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
