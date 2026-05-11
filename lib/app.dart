import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes/app_router.dart';
import 'utils/theme/theme.dart';
import 'providers/deferred_interaction_provider.dart';
import 'providers/interaction_providers.dart';

class HammeApp extends ConsumerStatefulWidget {
  const HammeApp({super.key});

  @override
  ConsumerState<HammeApp> createState() => _HammeAppState();
}

class _HammeAppState extends ConsumerState<HammeApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
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
    // hamme://reveal/<token>
    if (uri.scheme == 'hamme' && uri.host == 'reveal') {
      final token = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (token != null) {
        ref.read(deferredInteractionTokenProvider.notifier).state = token;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize the deferred interaction finalizer to listen for tokens
    ref.watch(deferredInteractionFinalizerProvider);

    return MaterialApp.router(
      title: 'Hamme',
      debugShowCheckedModeBanner: false,
      theme: TAppTheme.lightTheme,
      darkTheme: TAppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
