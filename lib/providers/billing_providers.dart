import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_exception.dart';
import '../models/app_user.dart';
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
    this.paymentAwaitingApproval = false,
    this.verificationRequired = false,
    this.restoring = false,
    this.error,
    this.restoreRequired = false,
  });

  /// Whether the user currently owns the Pro entitlement.
  final bool isPro;

  final bool restoreRequired;

  /// Whether the underlying store (Play/App Store) is reachable.
  final bool storeAvailable;

  /// Product details fetched from the store (price, title, etc.).
  final List<ProductDetails> products;

  /// A purchase is currently being processed.
  final bool purchasePending;
  final bool paymentAwaitingApproval;
  final bool verificationRequired;

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
    bool? restoreRequired,
    bool? storeAvailable,
    List<ProductDetails>? products,
    bool? purchasePending,
    bool? paymentAwaitingApproval,
    bool? verificationRequired,
    bool? restoring,
    Object? error = _sentinel,
  }) {
    return BillingState(
      isPro: isPro ?? this.isPro,
      restoreRequired: restoreRequired ?? this.restoreRequired,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      products: products ?? this.products,
      purchasePending: purchasePending ?? this.purchasePending,
      paymentAwaitingApproval:
          paymentAwaitingApproval ?? this.paymentAwaitingApproval,
      verificationRequired: verificationRequired ?? this.verificationRequired,
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

class BillingController extends Notifier<BillingState>
    with WidgetsBindingObserver {
  static const String _entitlementKey = 'pro_entitlement';

  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<bool>? _restoreCompleter;
  Future<void>? _serverRefreshInFlight;
  PurchaseDetails? _purchaseToRestore;
  String? _restoreUserId;
  bool _restoreSawPurchase = false;
  bool _disposed = false;
  int _entitlementRevision = 0;
  bool _verificationCanRetry = false;
  Future<void> _purchaseQueue = Future<void>.value();

  @override
  BillingState build() {
    ref.onDispose(() => _disposed = true);
    // Only initialize IAP on supported platforms (iOS, Android)
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      _iap = InAppPurchase.instance;
      WidgetsBinding.instance.addObserver(this);
      _subscription = _iap!.purchaseStream.listen(
        _enqueuePurchases,
        onError: (Object error) {
          state = state.copyWith(
            purchasePending: false,
            restoring: false,
            error:
                'Could not connect to the store. Check your connection and try again.',
          );
          _completeRestore(false);
        },
      );
      ref.onDispose(() {
        _disposed = true;
        WidgetsBinding.instance.removeObserver(this);
        _subscription?.cancel();
        _completeRestore(false);
      });
    }

    final initialUser = ref.read(authControllerProvider).valueOrNull?.user;

    // Reflect the server-side entitlement once the auth session resolves.
    ref.listen(authControllerProvider, (previous, next) {
      // A loading state still carries the previous session (e.g. while logging
      // out or deleting the account); acting on it would re-check the
      // entitlement of a user who is leaving.
      if (next.isLoading) return;
      final user = next.valueOrNull?.user;
      if (user?.id != previous?.valueOrNull?.user.id ||
          user?.isPro != previous?.valueOrNull?.user.isPro) {
        _entitlementRevision++;
      }
      if (user?.id != previous?.valueOrNull?.user.id) {
        _purchaseToRestore = null;
        _restoreUserId = null;
        _completeRestore(false);
        state = state.copyWith(
          restoreRequired: false,
          verificationRequired: false,
          purchasePending: false,
          paymentAwaitingApproval: false,
          restoring: false,
          error: null,
        );
      }
      final serverPro = user?.isPro ?? false;
      if (serverPro && !state.isPro) {
        state = state.copyWith(isPro: true);
        unawaited(_grantEntitlement());
      } else if (!serverPro && state.isPro) {
        // Server says free — revoke the local entitlement so the cache doesn't
        // keep the user in Pro after an admin downgrade or subscription expiry.
        state = state.copyWith(isPro: false);
        unawaited(_revokeEntitlement());
      }
      if (user != null) {
        // The session already carries the server's isPro, so only reconcile a
        // subscriber with the store, and only when a different user signs in —
        // not on every session write (app resume, profile edits).
        if (serverPro && user.id != previous?.valueOrNull?.user.id) {
          unawaited(_refreshServerEntitlement());
        }
      }
    });

    // Kick off async initialization without blocking provider creation.
    unawaited(_bootstrap());

    // Start from the session's entitlement so Pro users don't fetch the play
    // limit before _bootstrap has run.
    return BillingState(isPro: initialUser?.isPro ?? false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed ||
        state != AppLifecycleState.resumed ||
        ref.read(authControllerProvider).valueOrNull == null) {
      return;
    }
    unawaited(_refreshServerEntitlement());
    if (this.state.storeAvailable &&
        !this.state.restoring &&
        (this.state.paymentAwaitingApproval ||
            this.state.verificationRequired)) {
      unawaited(
        _restoreOwnedPurchases(showProgress: false, showNotFoundError: false),
      );
    }
  }

  /// Loads the persisted entitlement and queries the store for products.
  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    final savedEntitlement = prefs.getBool(_entitlementKey) ?? false;

    // Server is the source of truth when a session is available.
    final sessionPro = ref.read(authControllerProvider).value?.user.isPro;
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

    if (_disposed) return;
    // Store discovery may finish after sign-in, purchase verification or an
    // account switch. Read the current session rather than the old snapshot.
    state = state.copyWith(
      isPro: ref.read(authControllerProvider).valueOrNull?.user.isPro ?? false,
      storeAvailable: available,
    );
    // Free users' isPro already comes from the session; only a subscriber's
    // entitlement needs reconciling with the store.
    if (sessionPro == true) {
      unawaited(_refreshServerEntitlement());
    }

    if (!available || _iap == null) {
      debugPrint('[Billing] store not available on this device');
      return;
    }

    try {
      final response = await _iap!.queryProductDetails(ProProducts.ids);
      if (_disposed) return;
      if (response.error != null) {
        debugPrint('[Billing] queryProductDetails error: ${response.error}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[Billing] product ids not found: ${response.notFoundIDs}');
      }
      state = state.copyWith(products: response.productDetails);
    } catch (error) {
      debugPrint('[Billing] queryProductDetails failed: $error');
      if (_disposed) return;
      state = state.copyWith(error: 'Could not load products.');
    }
  }

  /// Starts the purchase flow for the Pro subscription.
  Future<void> buyPro() async {
    if (state.busy || state.restoreRequired || state.isPro) return;
    if (state.verificationRequired) {
      await restorePurchases();
      return;
    }
    state = state.copyWith(error: null);

    if (_iap != null && (!state.storeAvailable || state.proProduct == null)) {
      state = state.copyWith(purchasePending: true);
      try {
        final available = await _iap!.isAvailable();
        final products =
            available
                ? (await _iap!.queryProductDetails(
                  ProProducts.ids,
                )).productDetails
                : <ProductDetails>[];
        if (_disposed) return;
        state = state.copyWith(storeAvailable: available, products: products);
      } catch (error) {
        if (!_disposed) {
          state = state.copyWith(error: _storeErrorMessage(error));
        }
        return;
      } finally {
        if (!_disposed) state = state.copyWith(purchasePending: false);
      }
    }
    if (_iap == null || !state.storeAvailable) {
      state = state.copyWith(
        error: 'In-app purchases are not available on this platform.',
      );
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final restored = await _restoreOwnedPurchases(
        showProgress: false,
        showNotFoundError: false,
      );
      if (restored ||
          state.busy ||
          state.isPro ||
          state.restoreRequired ||
          state.error != null) {
        return;
      }
    }
    final product = state.proProduct;
    if (product == null) {
      state = state.copyWith(
        error: 'Pro plan is not available right now. Please try again later.',
      );
      return;
    }

    state = state.copyWith(
      purchasePending: true,
      paymentAwaitingApproval: false,
      error: null,
    );
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
        // the subscription. Query owned purchases and offer restoration to the current
        // Hamme profile instead of presenting an "already subscribed" failure.
        final restored = await _restoreOwnedPurchases(
          showProgress: false,
          showNotFoundError: false,
        );
        if (!restored && !state.restoreRequired) {
          state = state.copyWith(
            purchasePending: false,
            error:
                'Could not open checkout. Check your connection and try again.',
          );
        }
      }
    } catch (error) {
      debugPrint('[Billing] buyPro failed: $error');
      final message = error.toString().toLowerCase();
      if (message.contains('already_owned') ||
          message.contains('already owned') ||
          message.contains('duplicate_product')) {
        await _restoreOwnedPurchases(
          showProgress: true,
          showNotFoundError: true,
        );
        return;
      }
      state = state.copyWith(
        purchasePending: false,
        error: _storeErrorMessage(error),
      );
    }
  }

  String _storeErrorMessage(Object? error) {
    final text = error.toString().toLowerCase();
    if (text.contains('declin') ||
        text.contains('payment') ||
        text.contains('insufficient')) {
      return 'Payment could not be completed. Check your payment method in the store or choose another method, then try again.';
    }
    if (text.contains('network') ||
        text.contains('disconnect') ||
        text.contains('timeout') ||
        text.contains('service_unavailable')) {
      return 'The store could not connect. Check your internet connection and try again.';
    }
    return 'Purchase could not be completed. Check your payment method in the store and try again. If you were charged, use Restore instead of purchasing again.';
  }

  /// Restores previously purchased entitlements.
  Future<bool> restorePurchases() async {
    if (state.busy) return false;
    return _restoreOwnedPurchases(showProgress: true, showNotFoundError: true);
  }

  Future<bool> _restoreOwnedPurchases({
    required bool showProgress,
    required bool showNotFoundError,
  }) async {
    final existingRestore = _restoreCompleter;
    if (existingRestore != null) return existingRestore.future;
    if (_iap == null || !state.storeAvailable) {
      if (showProgress) {
        state = state.copyWith(
          error: 'In-app purchases are not available on this platform.',
        );
      }
      return false;
    }
    if (ref.read(authControllerProvider).value?.user == null) {
      state = state.copyWith(
        error: 'Finish setting up your Hamme profile before restoring Pro.',
      );
      return false;
    }
    state = state.copyWith(restoring: true, error: null);
    final restoreCompleter = Completer<bool>();
    _restoreCompleter = restoreCompleter;
    _restoreSawPurchase = false;
    try {
      final user = ref.read(authControllerProvider).value?.user;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result = await _iap!
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
            .queryPastPurchases(applicationUserName: user?.id);
        if (result.error != null) {
          throw const AppException('Could not query Google Play purchases.');
        }
        final ownedPro =
            result.pastPurchases
                .where((p) => ProProducts.ids.contains(p.productID))
                .toList();
        if (ownedPro.isEmpty) {
          state = state.copyWith(
            restoring: false,
            purchasePending: false,
            error:
                showNotFoundError
                    ? 'No active Pro subscription was found. Check the Google Play account used to purchase Pro.'
                    : null,
          );
          _completeRestore(false);
        } else {
          await _enqueuePurchases(ownedPro);
        }
        return restoreCompleter.future;
      }
      await _iap!.restorePurchases(applicationUserName: user?.id);
    } catch (error) {
      debugPrint('[Billing] restorePurchases failed: $error');
      state = state.copyWith(
        restoring: false,
        // Also clears purchasePending: the "already owned" recovery path
        // re-sets it to true before calling this with showProgress: false,
        // and nothing else would reset it if restorePurchases() throws.
        purchasePending: false,
        error: 'Could not check your store purchases. Please try again.',
      );
      if (!restoreCompleter.isCompleted) restoreCompleter.complete(false);
      if (identical(_restoreCompleter, restoreCompleter)) {
        _restoreCompleter = null;
      }
      return false;
    }

    // The actual result arrives via the purchase stream. If the store returns
    // no restored purchase, finish after a grace period. Android queries above
    // return an explicit result and never depend on this timer.
    Future<void>.delayed(const Duration(seconds: 15), () {
      if (!_disposed &&
          identical(_restoreCompleter, restoreCompleter) &&
          !_restoreSawPurchase) {
        state = state.copyWith(
          restoring: false,
          purchasePending: false,
          error:
              showNotFoundError ? 'No previous Pro purchase was found.' : null,
        );
        if (!restoreCompleter.isCompleted) restoreCompleter.complete(false);
        _restoreCompleter = null;
      }
    });
    return restoreCompleter.future;
  }

  Future<void> _enqueuePurchases(List<PurchaseDetails> purchases) {
    _purchaseQueue = _purchaseQueue
        .then((_) async {
          if (_disposed) return;
          await _onPurchasesUpdated(purchases);
        })
        .catchError((Object error) {
          debugPrint('[Billing] purchase processing failed: $error');
          if (_disposed) return;
          state = state.copyWith(
            purchasePending: false,
            restoring: false,
            error: 'Could not process your purchase. Please restore it again.',
          );
          _completeRestore(false);
        });
    return _purchaseQueue;
  }

  Future<void> _onPurchasesUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      bool verified = false;
      // On Android, backing out of the Play Billing sheet leaves no real
      // purchase to read a product id from: in_app_purchase_android emits a
      // synthetic PurchaseDetails with productID: '' for canceled/error
      // results. Only one purchase can be in flight at a time (buyPro()
      // returns early while state.busy), so still treat that as ours instead
      // of silently dropping it here and leaving purchasePending stuck true.
      final isUnattributedCancelOrError =
          purchase.productID.isEmpty &&
          (purchase.status == PurchaseStatus.canceled ||
              purchase.status == PurchaseStatus.error);
      if (!ProProducts.ids.contains(purchase.productID) &&
          !isUnattributedCancelOrError) {
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(
            purchasePending: true,
            paymentAwaitingApproval: true,
            restoring: false,
            error: null,
          );
          _completeRestore(false);
          break;
        case PurchaseStatus.error:
          state = state.copyWith(paymentAwaitingApproval: false);
          final errorText =
              '${purchase.error?.message ?? ''} ${purchase.error?.details ?? ''}'
                  .toLowerCase();
          if (errorText.contains('itemalreadyowned') ||
              errorText.contains('already owned') ||
              purchase.error?.code == 'item_already_owned' ||
              purchase.error?.code == '7') {
            state = state.copyWith(purchasePending: true, error: null);
            unawaited(
              _restoreOwnedPurchases(
                showProgress: false,
                showNotFoundError: true,
              ),
            );
            break;
          }
          state = state.copyWith(
            purchasePending: false,
            restoring: false,
            error: _storeErrorMessage(purchase.error),
          );
          _completeRestore(false);
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(paymentAwaitingApproval: false);
          state = state.copyWith(
            purchasePending: false,
            restoring: false,
            error: null,
          );
          _completeRestore(false);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          state = state.copyWith(
            purchasePending: true,
            paymentAwaitingApproval: false,
            error: null,
          );
          _restoreSawPurchase = true;
          final purchasingUserId =
              ref.read(authControllerProvider).valueOrNull?.user.id;
          final verificationError = await _verifyPurchase(purchase);
          if (_disposed) return;
          if (ref.read(authControllerProvider).valueOrNull?.user.id !=
              purchasingUserId) {
            continue;
          }
          if (verificationError == null) {
            verified = true;
            await _grantEntitlement();
            state = state.copyWith(
              isPro: true,
              verificationRequired: false,
              purchasePending: false,
              restoring: false,
              error: null,
            );
            _completeRestore(true);
          } else {
            state = state.copyWith(
              purchasePending: false,
              restoring: false,
              error: verificationError,
              verificationRequired:
                  _verificationCanRetry && !state.restoreRequired,
            );
            _completeRestore(false);
          }
          break;
      }

      // Finish only verified transactions; failed verification can be retried.
      if (purchase.pendingCompletePurchase &&
          verified &&
          !state.restoreRequired) {
        try {
          await _iap!.completePurchase(purchase);
        } catch (error) {
          debugPrint('[Billing] purchase completion failed: $error');
        }
      }
    }
  }

  /// Verifies the purchase with our backend, which validates the token against
  /// Google Play and grants the Pro entitlement on the user account.
  /// Returns null on success or an error message on failure.
  Future<String?> _verifyPurchase(PurchaseDetails purchase) async {
    _verificationCanRetry = false;
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) {
      _verificationCanRetry = true;
      return 'Could not read your store purchase. Tap Restore to try again. Do not purchase again.';
    }

    final verifyingUserId = ref.read(authControllerProvider).value?.user.id;
    try {
      final api = ref.read(apiServiceProvider);
      final platform =
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      final user = ref.read(authControllerProvider).value?.user;
      if (user == null) {
        return 'Finish setting up your Hamme profile before restoring Pro.';
      }
      final restoring =
          purchase.status == PurchaseStatus.restored ||
          _restoreCompleter != null;
      final response = await api.post(
        restoring ? '/billing/restore' : '/billing/verify',
        authenticated: true,
        body: {
          'platform': platform,
          'productId': purchase.productID,
          'purchaseToken': token,
          if (restoring) 'confirmTransfer': false,
        },
      );
      if (ref.read(authControllerProvider).value?.user.id != user.id) {
        return 'Your Hamme profile changed. Restore Pro again on your current profile.';
      }
      if (response is! Map<String, dynamic> ||
          response['isPro'] != true ||
          response['user'] is! Map<String, dynamic>) {
        _verificationCanRetry = true;
        return 'Could not verify your Pro subscription.';
      }
      ref
          .read(authControllerProvider.notifier)
          .setUser(AppUser.fromJson(response['user'] as Map<String, dynamic>));
      // A 2xx response means the backend verified the purchase and granted Pro.
      return null;
    } catch (error) {
      debugPrint('[Billing] backend verification failed: $error');
      if (error is AppException) {
        if (error.code == 'RESTORE_REQUIRED') {
          if (ref.read(authControllerProvider).value?.user.id !=
              verifyingUserId) {
            return 'Your profile changed. Please restore again.';
          }
          _purchaseToRestore = purchase;
          _restoreUserId = ref.read(authControllerProvider).value?.user.id;
          state = state.copyWith(restoreRequired: true);
          return 'An existing Pro subscription was found. Restore it to this profile.';
        }
        if (error.statusCode == null ||
            error.statusCode! >= 500 ||
            error.statusCode == 429) {
          _verificationCanRetry = true;
          return 'Your store purchase could not be verified yet. Check your connection and tap Restore to activate Pro. Do not purchase again.';
        }
        return error.message;
      }
      _verificationCanRetry = true;
      return 'Your store purchase could not be verified yet. Tap Restore to try again. Do not purchase again.';
    }
  }

  void dismissRestore() {
    _purchaseToRestore = null;
    _restoreUserId = null;
    state = state.copyWith(restoreRequired: false, error: null);
  }

  Future<bool> confirmRestore() async {
    final purchase = _purchaseToRestore;
    final userId = _restoreUserId;
    if (purchase == null || userId == null || state.busy) return false;
    state = state.copyWith(
      restoring: true,
      restoreRequired: false,
      error: null,
    );
    try {
      if (ref.read(authControllerProvider).value?.user.id != userId) {
        throw const AppException('Your profile changed. Please restore again.');
      }
      final response = await ref
          .read(apiServiceProvider)
          .post(
            '/billing/restore',
            authenticated: true,
            body: {
              'platform':
                  defaultTargetPlatform == TargetPlatform.iOS
                      ? 'ios'
                      : 'android',
              'productId': purchase.productID,
              'purchaseToken': purchase.verificationData.serverVerificationData,
              'confirmTransfer': true,
            },
          );
      if (ref.read(authControllerProvider).value?.user.id != userId) {
        return false;
      }
      if (response is! Map<String, dynamic> || response['isPro'] != true) {
        throw const AppException('Could not restore your Pro subscription.');
      }
      ref
          .read(authControllerProvider.notifier)
          .setUser(AppUser.fromJson(response['user'] as Map<String, dynamic>));
      await _grantEntitlement();
      state = state.copyWith(isPro: true);
      dismissRestore();
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap!.completePurchase(purchase);
        } catch (error) {
          debugPrint('[Billing] restored purchase completion failed: $error');
        }
      }
      return true;
    } catch (error) {
      state = state.copyWith(
        error:
            error is AppException
                ? error.message
                : 'Could not restore Pro. Please try again.',
      );
      return false;
    } finally {
      state = state.copyWith(restoring: false, purchasePending: false);
    }
  }

  void _completeRestore(bool restored) {
    final completer = _restoreCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(restored);
    }
    _restoreCompleter = null;
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
      final revision = _entitlementRevision;
      final userId = ref.read(authControllerProvider).value?.user.id;
      if (userId == null) return;
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/billing/status', authenticated: true);
      if (_disposed || revision != _entitlementRevision) return;
      if (ref.read(authControllerProvider).value?.user.id != userId) return;
      if (response is! Map<String, dynamic>) return;
      final entitlement = response['isPro'];
      if (entitlement is! bool) return;

      final user = response['user'];
      if (user is Map<String, dynamic>) {
        ref
            .read(authControllerProvider.notifier)
            .setUser(AppUser.fromJson(user));
      }
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
