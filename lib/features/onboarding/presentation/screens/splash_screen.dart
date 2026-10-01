import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/utils/constants/colors.dart';
import 'package:hamme_app/utils/constants/fonts.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The saved session couldn't be checked (offline, timeout, server error)
    // even after retries. The router keeps the user here instead of sending
    // them to onboarding, which would create a second account.
    final auth = ref.watch(authControllerProvider);
    final restoreFailed = auth.hasError && !auth.hasValue;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [TColors.hammePrimary, TColors.hammePrimaryDark],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: ScaleTransition(
                scale: _animation,
                child: FadeTransition(
                  opacity: _animation,
                  child: const _SplashWordmark(),
                ),
              ),
            ),
            if (restoreFailed)
              Positioned(
                left: 24,
                right: 24,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Couldn't connect to Hamme. Check your connection "
                        'and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TColors.white,
                          fontFamily: TFonts.nunito,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // While a retry runs the state is an error that is
                      // loading again.
                      auth.isLoading
                          ? const CircularProgressIndicator(
                            color: TColors.white,
                          )
                          : FilledButton(
                            onPressed:
                                () => ref.invalidate(authControllerProvider),
                            style: FilledButton.styleFrom(
                              backgroundColor: TColors.white,
                              foregroundColor: TColors.hammePrimaryDark,
                            ),
                            child: const Text('Retry'),
                          ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SplashWordmark extends StatelessWidget {
  const _SplashWordmark();

  @override
  Widget build(BuildContext context) {
    const wordmark = 'Hamme';
    const fontSize = 48.0;

    return SizedBox(
      key: const Key('splash-wordmark'),
      width: 176,
      height: 65,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              wordmark,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                foreground:
                    Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 12
                      ..strokeJoin = StrokeJoin.miter
                      ..color = Colors.black,
              ),
            ),
            const Text(
              wordmark,
              style: TextStyle(
                fontFamily: TFonts.nunito,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
