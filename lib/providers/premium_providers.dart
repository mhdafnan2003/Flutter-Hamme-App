import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/api_service.dart';
import 'api_providers.dart';

class PremiumState {
  const PremiumState({
    required this.isPro,
    required this.isBusy,
    required this.isStoreAvailable,
    required this.productDetails,
    this.message,
    this.manualOverride,
  });

  final bool isPro;
  final bool isBusy;
  final bool isStoreAvailable;
  final List<ProductDetails> productDetails;
  final String? message;
  final bool? manualOverride;

  PremiumState copyWith({
    bool? isPro,
    bool? isBusy,
    bool? isStoreAvailable,
    List<ProductDetails>? productDetails,
    String? message,
    bool clearMessage = false,
    bool? manualOverride,
    bool clearManualOverride = false,
  }) {
    return PremiumState(
      isPro: isPro ?? this.isPro,
      isBusy: isBusy ?? this.isBusy,
      isStoreAvailable: isStoreAvailable ?? this.isStoreAvailable,
      productDetails: productDetails ?? this.productDetails,
      message: clearMessage ? null : (message ?? this.message),
      manualOverride:
          clearManualOverride ? null : (manualOverride ?? this.manualOverride),
    );
  }
}

final premiumControllerProvider =
    AsyncNotifierProvider<PremiumController, PremiumState>(
      PremiumController.new,
    );

class PremiumController extends AsyncNotifier<PremiumState> {
  static const String _proProductId = 'hamme_pro_weekly';
  static const String _premiumActiveKey = 'premium_active';
  static const String _manualOverrideKey = 'premium_manual_override';
  static const String _premiumLastSourceKey = 'premium_last_source';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  ApiService get _api => ref.read(apiServiceProvider);

  @override
  Future<PremiumState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final bool premiumActive = prefs.getBool(_premiumActiveKey) ?? false;
    final int? manualRaw = prefs.getInt(_manualOverrideKey);
    final bool? manualOverride = _decodeManualOverride(manualRaw);

    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onDone: () => _purchaseSub?.cancel(),
      onError: (Object e) {
        final current = state.valueOrNull;
        if (current != null) {
          state = AsyncData(current.copyWith(message: 'Purchase stream error: $e'));
        }
      },
    );
    ref.onDispose(() => _purchaseSub?.cancel());

    final bool storeAvailable = await _iap.isAvailable();
    final List<ProductDetails> products = await _loadProducts(storeAvailable);
    final backendEntitlement = await _fetchBackendEntitlement();
    final persisted = backendEntitlement ?? premiumActive;
    final effectivePro = manualOverride ?? persisted;

    return PremiumState(
      isPro: effectivePro,
      isBusy: false,
      isStoreAvailable: storeAvailable,
      productDetails: products,
      manualOverride: manualOverride,
      message: backendEntitlement == null
          ? null
          : (backendEntitlement ? 'PRO entitlement synced.' : 'No active PRO entitlement.'),
    );
  }

  Future<void> purchasePro() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.isStoreAvailable) {
      state = AsyncData(
        current.copyWith(message: 'Store is unavailable on this build/device.'),
      );
      return;
    }

    final product = current.productDetails
        .where((p) => p.id == _proProductId)
        .cast<ProductDetails?>()
        .firstWhere((p) => p != null, orElse: () => null);
    if (product == null) {
      state = AsyncData(
        current.copyWith(
          message:
              'Product "$_proProductId" not found. Check Play Console product ID.',
        ),
      );
      return;
    }

    state = AsyncData(current.copyWith(isBusy: true, clearMessage: true));
    final launched = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );

    if (!launched) {
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          message: 'Purchase flow could not be started.',
        ),
      );
    }
  }

  Future<void> restorePurchases() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.isStoreAvailable) {
      state = AsyncData(
        current.copyWith(message: 'Store is unavailable on this build/device.'),
      );
      return;
    }

    state = AsyncData(
      current.copyWith(
        isBusy: true,
        message: 'Checking Google Play purchases...',
      ),
    );
    await _iap.restorePurchases();
    final synced = await _fetchBackendEntitlement();
    final manual = state.valueOrNull?.manualOverride;
    state = AsyncData(
      (state.valueOrNull ?? current).copyWith(
        isBusy: false,
        isPro: manual ?? (synced ?? current.isPro),
        message: 'Restore request sent. Waiting for Play response...',
      ),
    );
  }

  Future<void> refreshProducts() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final available = await _iap.isAvailable();
    final products = await _loadProducts(available);
    final backendEntitlement = await _fetchBackendEntitlement();
    final manual = current.manualOverride;

    state = AsyncData(
      current.copyWith(
        isStoreAvailable: available,
        productDetails: products,
        isPro: manual ?? (backendEntitlement ?? current.isPro),
        message: 'Store data refreshed.',
      ),
    );
  }

  Future<void> setManualOverride(bool? value) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();

    if (value == null) {
      await prefs.remove(_manualOverrideKey);
      final backendEntitlement = await _fetchBackendEntitlement();
      final persistedPro = backendEntitlement ?? (prefs.getBool(_premiumActiveKey) ?? false);
      state = AsyncData(
        current.copyWith(
          isPro: persistedPro,
          clearManualOverride: true,
          message: 'Manual override cleared.',
        ),
      );
      return;
    }

    await prefs.setInt(_manualOverrideKey, value ? 1 : 0);
    state = AsyncData(
      current.copyWith(
        isPro: value,
        manualOverride: value,
        message: 'Manual override applied: PRO=${value ? 'true' : 'false'}.',
      ),
    );
  }

  Future<void> debugVerifyMockPurchase({required bool active}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        isBusy: true,
        message: 'Verifying mock purchase with backend...',
      ),
    );
    final token = active ? 'mock_active_token' : 'mock_expired_token';
    try {
      final response = await _api.post(
            '/billing/verify/android',
            authenticated: true,
            body: {'purchaseToken': token},
          )
          as Map<String, dynamic>;
      final isPro = response['isPro'] == true;
      await _persistPremiumActive(isPro, source: 'backend_mock');
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        latest.copyWith(
          isBusy: false,
          isPro: latest.manualOverride ?? isPro,
          message:
              'Mock verification complete: ${isPro ? 'PRO active' : 'PRO inactive'}.',
        ),
      );
    } catch (e) {
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        latest.copyWith(
          isBusy: false,
          message: 'Mock verification failed: $e',
        ),
      );
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != _proProductId) continue;

      if (purchase.status == PurchaseStatus.pending) {
        final current = state.valueOrNull;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              isBusy: true,
              message: 'Purchase pending...',
            ),
          );
        }
      }

      if (purchase.status == PurchaseStatus.error) {
        final current = state.valueOrNull;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              isBusy: false,
              message: purchase.error?.message ?? 'Purchase failed.',
            ),
          );
        }
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final verified = await _verifyPurchaseWithBackend(purchase);
        final current = state.valueOrNull;

        if (current != null) {
          final effective = current.manualOverride ?? verified;
          state = AsyncData(
            current.copyWith(
              isPro: effective,
              isBusy: false,
              message: verified
                  ? (purchase.status == PurchaseStatus.restored
                      ? 'Restore successful. PRO unlocked.'
                      : 'Purchase successful. PRO unlocked.')
                  : 'Purchase found, but backend verification did not confirm active PRO.',
            ),
          );
        }
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<bool> _verifyPurchaseWithBackend(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) return false;

    try {
      final response = await _api.post(
            '/billing/verify/android',
            authenticated: true,
            body: {'purchaseToken': token},
          )
          as Map<String, dynamic>;

      final isPro = response['isPro'] == true;
      await _persistPremiumActive(isPro, source: (response['source'] as String?) ?? 'google_play');
      return isPro;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> _fetchBackendEntitlement() async {
    try {
      final response =
          await _api.get('/billing/entitlement', authenticated: true)
              as Map<String, dynamic>;
      final isPro = response['isPro'] == true;
      await _persistPremiumActive(isPro, source: (response['source'] as String?) ?? 'backend_sync');
      return isPro;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistPremiumActive(bool value, {required String source}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumActiveKey, value);
    await prefs.setString(_premiumLastSourceKey, source);
  }

  Future<List<ProductDetails>> _loadProducts(bool storeAvailable) async {
    if (!storeAvailable) return <ProductDetails>[];
    final response = await _iap.queryProductDetails({_proProductId});
    return response.productDetails;
  }

  bool? _decodeManualOverride(int? value) {
    if (value == null) return null;
    return value == 1;
  }
}
