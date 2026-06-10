import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // The server is the source of truth; OR it with any locally cached value.
    final sessionPro = ref.read(authControllerProvider).value?.user.isPro ?? false;
    final entitlement = savedEntitlement || sessionPro;
    if (sessionPro && !savedEntitlement) {
      await prefs.setBool(_entitlementKey, true);
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
    } catch (error) {
      debugPrint('[Billing] queryProductDetails failed: $error');
      state = state.copyWith(error: 'Could not load products.');
    }
  }

  /// Starts the purchase flow for the Pro subscription.
  Future<void> buyPro() async {
    if (state.busy) return;

    if (_iap == null || !state.storeAvailable) {
      state = state.copyWith(error: 'In-app purchases are not available on this platform.');
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
      final purchaseParam = PurchaseParam(productDetails: product);
      // Subscriptions and non-consumables both use buyNonConsumable.
      final started = await _iap!.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) {
        state = state.copyWith(
          purchasePending: false,
          error: 'Could not start the purchase.',
        );
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
  Future<void> restorePurchases() async {
    if (state.busy) return;
    if (_iap == null) {
      state = state.copyWith(error: 'In-app purchases are not available on this platform.');
      return;
    }
    state = state.copyWith(restoring: true, error: null);
    try {
      await _iap!.restorePurchases();
    } catch (error) {
      debugPrint('[Billing] restorePurchases failed: $error');
      state = state.copyWith(
        restoring: false,
        error: 'Could not restore purchases.',
      );
    }
    // The actual result arrives via the purchase stream. Clear the spinner
    // after a short grace period in case there are no purchases to restore.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (state.restoring) {
        state = state.copyWith(restoring: false);
      }
    });
  }

  Future<void> _onPurchasesUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(purchasePending: true, error: null);
          break;
        case PurchaseStatus.error:
          state = state.copyWith(
            purchasePending: false,
            restoring: false,
            error: purchase.error?.message ?? 'Purchase failed.',
          );
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(purchasePending: false, restoring: false);
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
          } else {
            state = state.copyWith(
              purchasePending: false,
              restoring: false,
              error: 'Could not verify purchase.',
            );
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
      await api.post(
        '/billing/verify',
        authenticated: true,
        body: {
          'platform': platform,
          'productId': purchase.productID,
          'purchaseToken': token,
        },
      );
      // A 2xx response means the backend verified the purchase and granted Pro.
      return true;
    } catch (error) {
      debugPrint('[Billing] backend verification failed: $error');
      return false;
    }
  }

  Future<void> _grantEntitlement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entitlementKey, true);
  }
}
