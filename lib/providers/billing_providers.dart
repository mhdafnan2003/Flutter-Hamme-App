import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

/// Product identifiers configured in the Google Play Console (and App Store
/// Connect for iOS). These MUST match the product IDs you create in the store.
///
/// For a subscription, create a subscription product in Play Console and use
/// its product ID here (e.g. `hamme_pro_weekly`).
class ProProducts {
  ProProducts._();

  /// The weekly Pro subscription product id.
  static const String weekly = 'hamme_pro_weekly';

  /// All product ids we query from the store.
  static const Set<String> ids = <String>{weekly};
}

/// Immutable snapshot of the billing/entitlement state.
class BillingState {
  const BillingState({
    this.isPro = false,
    this.storeAvailable = false,
    this.products = const <ProductDetails>[],
    this.purchasePending = false,
    this.restoring = false,
    this.error,
  });

  /// Whether the user currently owns the Pro entitlement.
  final bool isPro;

  /// Whether the underlying store (Play/App Store) is reachable.
  final bool storeAvailable;

  /// Product details fetched from the store (price, title, etc.).
  final List<ProductDetails> products;

  /// A purchase is currently being processed.
  final bool purchasePending;

  /// A restore-purchases call is in flight.
  final bool restoring;

  /// Last user-facing error, if any.
  final String? error;

  bool get busy => purchasePending || restoring;

  ProductDetails? get proProduct {
    for (final product in products) {
      if (product.id == ProProducts.weekly) return product;
    }
    return null;
  }

  BillingState copyWith({
    bool? isPro,
    bool? storeAvailable,
    List<ProductDetails>? products,
    bool? purchasePending,
    bool? restoring,
    Object? error = _sentinel,
  }) {
    return BillingState(
      isPro: isPro ?? this.isPro,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      products: products ?? this.products,
      purchasePending: purchasePending ?? this.purchasePending,
      restoring: restoring ?? this.restoring,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  static const Object _sentinel = Object();
}

final billingControllerProvider =
    NotifierProvider<BillingController, BillingState>(BillingController.new);

/// Convenience provider exposing just the Pro entitlement flag.
final isProProvider = Provider<bool>(
  (ref) => ref.watch(billingControllerProvider.select((s) => s.isPro)),
);

class BillingController extends Notifier<BillingState> {
  static const String _entitlementKey = 'pro_entitlement';

  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<bool>? _restoreCompleter;
  Future<void>? _serverRefreshInFlight;
  bool _allowSessionRecovery = false;
  bool _automaticRestoreAttempted = false;

  @override
  BillingState build() {
    // Only initialize IAP on supported platforms (iOS, Android)
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      _iap = InAppPurchase.instance;
      _subscription = _iap!.purchaseStream.listen(
        _onPurchasesUpdated,
        onError: (Object error) {
          state = state.copyWith(
            purchasePending: false,
            restoring: false,
            error: 'Purchase stream error: $error',
          );
        },
      );
      ref.onDispose(() => _subscription?.cancel());
    }

    // Reflect the server-side entitlement once the auth session resolves.
    ref.listen(authControllerProvider, (previous, next) {
      final serverPro = next.value?.user.isPro ?? false;
      if (serverPro && !state.isPro) {
        state = state.copyWith(isPro: true);
        unawaited(_grantEntitlement());
      } else if (!serverPro && state.isPro) {
        // Server says free — revoke the local entitlement so the cache doesn't
        // keep the user in Pro after an admin downgrade or subscription expiry.
        state = state.copyWith(isPro: false);
        unawaited(_revokeEntitlement());
      }
      if (next.value?.user != null) {
        unawaited(_refreshServerEntitlement());
      } else if (!next.isLoading && !next.hasError) {
        unawaited(_maybeRestoreAfterReinstall());
      }
    });

    // Kick off async initialization without blocking provider creation.
    unawaited(_bootstrap());

    return const BillingState();
  }

  /// Loads the persisted entitlement and queries the store for products.
  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEntitlement = prefs.getBool(_entitlementKey) ?? false;

    // Server is the source of truth when a session is available.
    final sessionPro = ref.read(authControllerProvider).value?.user.isPro;
    final entitlement = sessionPro ?? savedEntitlement;
    if (sessionPro == true && !savedEntitlement) {
      await prefs.setBool(_entitlementKey, true);
    } else if (sessionPro == false && savedEntitlement) {
      // Server explicitly says free — clear stale cached entitlement.
      await prefs.setBool(_entitlementKey, false);
    }

    bool available = false;
    if (_iap != null) {
      try {
        available = await _iap!.isAvailable();
      } catch (error) {
        debugPrint('[Billing] isAvailable failed: $error');
      }
    }

    state = state.copyWith(isPro: entitlement, storeAvailable: available);
    if (sessionPro != null) {
      unawaited(_refreshServerEntitlement());
    }

    if (!available || _iap == null) {
      debugPrint('[Billing] store not available on this device');
      return;
    }

    try {
      final response = await _iap!.queryProductDetails(ProProducts.ids);
      if (response.error != null) {
        debugPrint('[Billing] queryProductDetails error: ${response.error}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[Billing] product ids not found: ${response.notFoundIDs}');
      }
      state = state.copyWith(products: response.productDetails);
      unawaited(_maybeRestoreAfterReinstall());
    } catch (error) {
      debugPrint('[Billing] queryProductDetails failed: $error');
      state = state.copyWith(error: 'Could not load products.');
    }
  }

  /// Starts the purchase flow for the Pro subscription.
  Future<void> buyPro() async {
    if (state.busy) return;

    if (_iap == null || !state.storeAvailable) {
      state = state.copyWith(
        error: 'In-app purchases are not available on this platform.',
      );
      return;
    }

    final product = state.proProduct;
    if (product == null) {
      state = state.copyWith(
        error: 'Pro plan is not available right now. Please try again later.',
      );
      return;
    }

    state = state.copyWith(purchasePending: true, error: null);
    try {
      final user = ref.read(authControllerProvider).value?.user;
      if (user == null) {
        state = state.copyWith(
          purchasePending: false,
          error: 'Please sign in before purchasing Pro.',
        );
        return;
      }
      // The opaque Hamme user id is forwarded to Google as the obfuscated
      // account id. RTDN can then attribute an initial purchase even if its
      // notification reaches the backend before the app verification call.
      final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: user.id,
      );
      // Subscriptions and non-consumables both use buyNonConsumable.
      final started = await _iap!.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!started) {
        // Google commonly returns false when this Play account already owns
        // the subscription. Query owned purchases and recover the original
        // Hamme profile instead of presenting an "already subscribed" failure.
        final restored = await _restoreOwnedPurchases(
          showProgress: false,
          showNotFoundError: false,
          allowSessionRecovery: true,
        );
        if (!restored) {
          state = state.copyWith(
            purchasePending: false,
            error: 'Could not start the purchase.',
          );
        }
      }
    } catch (error) {
      debugPrint('[Billing] buyPro failed: $error');
      state = state.copyWith(
        purchasePending: false,
        error: 'Purchase failed. Please try again.',
      );
    }
  }

  /// Restores previously purchased entitlements.
  Future<bool> restorePurchases() async {
    if (state.busy) return false;
    return _restoreOwnedPurchases(
      showProgress: true,
      showNotFoundError: true,
      allowSessionRecovery: true,
    );
  }

  /// On a fresh Android installation, local auth storage can be gone while the
  /// Play account still owns Pro. Query Play once and let the verified purchase
  /// recover the original Hamme session automatically.
  Future<void> _maybeRestoreAfterReinstall() async {
    if (_automaticRestoreAttempted ||
        defaultTargetPlatform != TargetPlatform.android ||
        _iap == null ||
        !state.storeAvailable) {
      return;
    }
    final auth = ref.read(authControllerProvider);
    if (auth.isLoading || auth.hasError || auth.value?.user != null) return;

    _automaticRestoreAttempted = true;
    await _restoreOwnedPurchases(
      showProgress: false,
      showNotFoundError: false,
      allowSessionRecovery: true,
    );
  }

  Future<bool> _restoreOwnedPurchases({
    required bool showProgress,
    required bool showNotFoundError,
    required bool allowSessionRecovery,
  }) async {
    final existingRestore = _restoreCompleter;
    if (existingRestore != null) return existingRestore.future;
    if (_iap == null) {
      if (showProgress) {
        state = state.copyWith(
          error: 'In-app purchases are not available on this platform.',
        );
      }
      return false;
    }
    if (showProgress) {
      state = state.copyWith(restoring: true, error: null);
    }
    final restoreCompleter = Completer<bool>();
    _restoreCompleter = restoreCompleter;
    _allowSessionRecovery = allowSessionRecovery;
    try {
      final user = ref.read(authControllerProvider).value?.user;
      await _iap!.restorePurchases(applicationUserName: user?.id);
    } catch (error) {
      debugPrint('[Billing] restorePurchases failed: $error');
      state = state.copyWith(
        restoring: false,
        error: showProgress ? 'Could not restore purchases.' : null,
      );
      if (!restoreCompleter.isCompleted) restoreCompleter.complete(false);
      if (identical(_restoreCompleter, restoreCompleter)) {
        _restoreCompleter = null;
        _allowSessionRecovery = false;
      }
      return false;
    }

    // The actual result arrives via the purchase stream. If the store returns
    // no restored purchase, finish after a short grace period.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (identical(_restoreCompleter, restoreCompleter)) {
        state = state.copyWith(
          restoring: false,
          purchasePending: false,
          error:
              showNotFoundError ? 'No previous Pro purchase was found.' : null,
        );
        if (!restoreCompleter.isCompleted) restoreCompleter.complete(false);
        _restoreCompleter = null;
        _allowSessionRecovery = false;
      }
    });
    return restoreCompleter.future;
  }

  Future<void> _onPurchasesUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!ProProducts.ids.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(purchasePending: true, error: null);
          break;
        case PurchaseStatus.error:
          final errorText =
              '${purchase.error?.message ?? ''} ${purchase.error?.details ?? ''}'
                  .toLowerCase();
          if (errorText.contains('itemalreadyowned') ||
              errorText.contains('already owned')) {
            state = state.copyWith(purchasePending: true, error: null);
            unawaited(
              _restoreOwnedPurchases(
                showProgress: false,
                showNotFoundError: true,
                allowSessionRecovery: true,
              ),
            );
            break;
          }
          state = state.copyWith(
            purchasePending: false,
            restoring: false,
            error: purchase.error?.message ?? 'Purchase failed.',
          );
          _completeRestore(false);
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(purchasePending: false, restoring: false);
          _completeRestore(false);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // IMPORTANT: In production you should verify the purchase server-side
          // before granting entitlement. See _verifyPurchase below.
          final valid = await _verifyPurchase(purchase);
          if (valid) {
            await _grantEntitlement();
            state = state.copyWith(
              isPro: true,
              purchasePending: false,
              restoring: false,
              error: null,
            );
            _completeRestore(true);
          } else {
            state = state.copyWith(
              purchasePending: false,
              restoring: false,
              error: 'Could not verify purchase.',
            );
            _completeRestore(false);
          }
          break;
      }

      // Always complete the purchase so the store stops re-delivering it.
      if (purchase.pendingCompletePurchase) {
        await _iap!.completePurchase(purchase);
      }
    }
  }

  /// Verifies the purchase with our backend, which validates the token against
  /// Google Play and grants the Pro entitlement on the user account.
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) return false;

    try {
      final api = ref.read(apiServiceProvider);
      final platform =
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      final recoverSession =
          _allowSessionRecovery ||
          ref.read(authControllerProvider).value?.user == null;
      final response = await api.post(
        recoverSession ? '/billing/restore-session' : '/billing/verify',
        authenticated: !recoverSession,
        body: {
          'platform': platform,
          'productId': purchase.productID,
          'purchaseToken': token,
        },
      );
      if (recoverSession) {
        if (response is! Map<String, dynamic>) return false;
        final session = AuthSession.fromJson(response);
        await ref
            .read(authControllerProvider.notifier)
            .acceptBillingRestoredSession(session);
      }
      // A 2xx response means the backend verified the purchase and granted Pro.
      return true;
    } catch (error) {
      debugPrint('[Billing] backend verification failed: $error');
      return false;
    }
  }

  void _completeRestore(bool restored) {
    final completer = _restoreCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(restored);
    }
    _restoreCompleter = null;
    _allowSessionRecovery = false;
  }

  /// Reconciles the cached entitlement with Google through the backend. RTDN
  /// keeps the server current, while this check repairs any missed/delayed push.
  Future<void> _refreshServerEntitlement() {
    _serverRefreshInFlight ??= _doRefreshServerEntitlement();
    return _serverRefreshInFlight!.whenComplete(() {
      _serverRefreshInFlight = null;
    });
  }

  Future<void> _doRefreshServerEntitlement() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/billing/status', authenticated: true);
      if (response is! Map<String, dynamic>) return;
      final entitlement = response['isPro'];
      if (entitlement is! bool) return;

      state = state.copyWith(isPro: entitlement);
      if (entitlement) {
        await _grantEntitlement();
      } else {
        await _revokeEntitlement();
      }
    } catch (error) {
      // A reconciliation failure must not interrupt app startup. The backend
      // remains authoritative and RTDN/status will repair state on a later try.
      debugPrint('[Billing] server entitlement refresh failed: $error');
    }
  }

  Future<void> _grantEntitlement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entitlementKey, true);
  }

  Future<void> _revokeEntitlement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entitlementKey, false);
  }
}
