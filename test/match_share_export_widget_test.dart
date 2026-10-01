import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/features/play/presentation/widgets/match_share_export_widget.dart';
import 'package:hamme_app/models/interaction_type.dart';
import 'package:hamme_app/models/interaction_result.dart';
import 'package:hamme_app/models/interaction_record.dart';
import 'package:hamme_app/models/app_user.dart';
import 'package:hamme_app/features/play/presentation/widgets/match_success_overlay.dart';
import 'safety_test_fakes.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      for (final font in ['Nunito', 'SchibstedGrotesk']) {
        await (FontLoader(
          font == 'SchibstedGrotesk' ? 'Schibsted Grotesk' : font,
        )..addFont(
          rootBundle.load('assets/fonts/$font-VariableFont_wght.ttf'),
        )).load();
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(key: const Key('capture'), child: child),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('anonymous share omits both match and interaction identity', (
    tester,
  ) async {
    final interaction = InteractionRecord(
      id: 'vote',
      toUser: 'me',
      type: InteractionType.friend,
      createdAt: DateTime(2026),
      fromUserName: 'Fallback Identity',
      fromUserProfileImageUrl: 'https://example.com/fallback-avatar.png',
    );
    final named = testNamedMatch(
      'match',
      userId: 'other',
      name: 'Matched Identity',
    ).copyWith(
      matchedUser: const AppUser(
        id: 'other',
        name: 'Matched Identity',
        email: '',
        instagramId: 'private-handle',
        shareCode: 'code',
        avatarUrl: 'https://example.com/matched-avatar.png',
      ),
    );
    final result = InteractionResult(
      interaction: interaction,
      matched: true,
      match: named.copyWith(anonymous: true),
    );
    final export = MatchShareExportWidget.fromResult(
      result: result,
      myImageUrl: null,
    );
    expect(export.otherName, 'Anonymous');
    expect(export.otherImageUrl, isNull);
    await pump(tester, export, const Size(393, 852));
    expect(find.textContaining('Matched Identity'), findsNothing);
    expect(find.textContaining('Fallback Identity'), findsNothing);
    expect(
      tester
          .widget<MatchAvatarPair>(find.byType(MatchAvatarPair))
          .plainOtherAvatar,
      isTrue,
    );
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .where((image) => image.image is NetworkImage),
      isEmpty,
    );
    final namedExport = MatchShareExportWidget.fromResult(
      result: result.copyWith(match: named),
    );
    expect(namedExport.otherName, 'Matched Identity');
    expect(namedExport.otherImageUrl, 'https://example.com/matched-avatar.png');
    expect(namedExport.anonymous, isFalse);
    final fallbackExport = MatchShareExportWidget.fromResult(
      result: result.copyWith(match: null),
    );
    expect(fallbackExport.otherName, 'Fallback Identity');
    expect(
      fallbackExport.otherImageUrl,
      'https://example.com/fallback-avatar.png',
    );
    final missingMatchIdentity = named.copyWith(
      matchedUser: const AppUser(
        id: 'other',
        name: '',
        email: '',
        instagramId: '',
        shareCode: '',
      ),
    );
    final anonymousFallback = MatchShareExportWidget.fromResult(
      result: result.copyWith(
        match: missingMatchIdentity.copyWith(anonymous: true),
      ),
    );
    expect(anonymousFallback.otherName, 'Anonymous');
    expect(anonymousFallback.otherImageUrl, isNull);
  });
  for (final type in InteractionType.values) {
    for (final size in [
      const Size(393, 852),
      const Size(1080, 1920),
      const Size(320, 480),
    ]) {
      testWidgets('match story $type fits uniformly at $size', (tester) async {
        await pump(
          tester,
          MatchShareExportWidget(type: type, otherName: 'Ava'),
          size,
        );
        final scale = (size.width / 393).clamp(0, size.height / 852);
        final card = tester.getRect(
          find.byKey(const Key('match-export-outer-card')),
        );
        expect(card.width, closeTo(361 * scale, .1));
        expect(card.height, closeTo(225 * scale, .1));
        expect(
          card.top,
          closeTo((size.height - 852 * scale) / 2 + 278 * scale, .1),
        );
        expect(
          find.text(
            'Ava also chose ${type.name[0].toUpperCase()}${type.name.substring(1)}.',
          ),
          findsOneWidget,
        );
        expect(find.text('Reply'), findsNothing);
        expect(tester.takeException(), isNull);
        if (size.width == 393 && const bool.fromEnvironment('UI_SCREENSHOTS')) {
          final context = tester.element(find.byKey(const Key('capture')));
          await tester.runAsync(() async {
            for (final img in tester.widgetList<Image>(find.byType(Image))) {
              await precacheImage(img.image, context);
            }
          });
          await tester.pump();
          await tester.runAsync(() async {
            final image =
                await tester
                    .renderObject<RenderRepaintBoundary>(
                      find.byKey(const Key('capture')),
                    )
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '${Directory.systemTemp.path}/hamme-ui-review/app-export-${type.name}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
