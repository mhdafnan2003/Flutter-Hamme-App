import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes/app_router.dart';
import 'utils/theme/theme.dart';
import 'providers/deferred_interaction_provider.dart';
import 'models/interaction_type.dart';
import 'providers/interaction_providers.dart';
import 'core/constants/app_constants.dart';
import 'core/services/install_referrer_service.dart';

class HammeApp extends ConsumerStatefulWidget {
  const HammeApp({super.key});

  @override
  ConsumerState<HammeApp> createState() => _HammeAppState();
}

class _HammeAppState extends ConsumerState<HammeApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final InstallReferrerService _installReferrerService = InstallReferrerService();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool _referrerChecked = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initInstallReferrer();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Check initial link if app was opened from a link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Listen to incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('[DeepLink] Incoming: $uri');
    if (uri.scheme == 'hamme') {
      if (uri.host == 'reveal') {
        final token = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (token != null) {
          ref.read(deferredInteractionTokenProvider.notifier).state = token;
        }
      }

      if (uri.host == 'open') {
        final token = uri.queryParameters['token'];
        final shareCode = uri.queryParameters['code'];
        final typeValue = uri.queryParameters['type'];

        if (token != null && token.isNotEmpty) {
          ref.read(deferredInteractionTokenProvider.notifier).state = token;
        }

        if (shareCode != null && shareCode.isNotEmpty) {
          ref.read(deferredShareCodeProvider.notifier).state = shareCode;
        }

        final parsedType = _parseInteractionType(typeValue);
        if (parsedType != null) {
          ref.read(deferredInteractionTypeProvider.notifier).state = parsedType;
        }

        debugPrint('[DeepLink] parsed open link: code=$shareCode type=$typeValue token=${token != null}');
      }
    }

    if (uri.scheme == 'https' && uri.host == AppConstants.appHost) {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'u') {
        final shareCode = segments[1];
        ref.read(deferredShareCodeProvider.notifier).state = shareCode;
        debugPrint('[DeepLink] parsed web link: code=$shareCode');
      }
    }
  }

  Future<void> _initInstallReferrer() async {
    if (_referrerChecked) return;
    _referrerChecked = true;

    final payload = await _installReferrerService.readPayload();
    if (payload == null || !payload.hasUsefulData) return;

    if (payload.token != null && payload.token!.isNotEmpty) {
      ref.read(deferredInteractionTokenProvider.notifier).state = payload.token;
    }
    if (payload.shareCode != null && payload.shareCode!.isNotEmpty) {
      ref.read(deferredShareCodeProvider.notifier).state = payload.shareCode;
    }
    final parsedType = _parseInteractionType(payload.type);
    if (parsedType != null) {
      ref.read(deferredInteractionTypeProvider.notifier).state = parsedType;
    }

    debugPrint(
      '[InstallReferrer] parsed: token=${payload.token != null} code=${payload.shareCode}',
    );
  }

  InteractionType? _parseInteractionType(String? value) {
    if (value == null || value.isEmpty) return null;
    switch (value.toLowerCase()) {
      case 'crush':
        return InteractionType.crush;
      case 'friend':
        return InteractionType.friend;
      case 'frenemy':
      case 'ameny':
        return InteractionType.frenemy;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize the deferred interaction finalizer to listen for tokens
    ref.watch(deferredInteractionFinalizerProvider);
    ref.listen<String?>(deferredInteractionErrorProvider, (_, message) {
      if (message == null || message.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = _scaffoldMessengerKey.currentState;
        if (messenger == null) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () => messenger.hideCurrentSnackBar(),
              ),
            ),
          );
        ref.read(deferredInteractionErrorProvider.notifier).state = null;
      });
    });

    return MaterialApp.router(
      title: 'Hamme',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: TAppTheme.lightTheme,
      darkTheme: TAppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
