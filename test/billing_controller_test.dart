import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:hamme_app/core/services/api_service.dart';
import 'package:hamme_app/core/utils/app_exception.dart';
import 'package:hamme_app/models/app_user.dart';
import 'package:hamme_app/models/auth_session.dart';
import 'package:hamme_app/providers/api_providers.dart';
import 'package:hamme_app/providers/auth_providers.dart';
import 'package:hamme_app/providers/billing_providers.dart';
import 'package:hamme_app/providers/play_limit_provider.dart';
import 'package:hamme_app/models/play_limit_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

const user = AppUser(
  id: 'tester',
  name: 'Tester',
  email: '',
  instagramId: '',
  shareCode: 'test',
);

class TestAuth extends AuthController {
  @override
  Future<AuthSession?> build() async =>
      const AuthSession(user: user, accessToken: 'test');
  @override
  void setUser(AppUser user) =>
      state = AsyncData(AuthSession(user: user, accessToken: 'test'));
}

class TestApi implements ApiService {
  Object? failure;
  int verifications = 0;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = false,
  }) async => {'isPro': true, 'user': user.copyWith(isPro: true).toJson()};
  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    verifications++;
    if (failure != null) throw failure!;
    return {'isPro': true, 'user': user.copyWith(isPro: true).toJson()};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAndroidAddition extends InAppPurchasePlatformAddition
    implements InAppPurchaseAndroidPlatformAddition {
  List<GooglePlayPurchaseDetails> owned = [];
  @override
  Future<QueryPurchaseDetailsResponse> queryPastPurchases({
    String? applicationUserName,
  }) async => QueryPurchaseDetailsResponse(pastPurchases: owned);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GooglePlayPurchaseDetails androidPurchase(PurchaseStateWrapper status) =>
    GooglePlayPurchaseDetails.fromPurchase(
      PurchaseWrapper(
        orderId: 'test-order',
        packageName: 'com.hamme.app',
        purchaseTime: 0,
        purchaseToken: 'test-token',
        signature: '',
        products: [ProProducts.weekly],
        isAutoRenewing: true,
        originalJson: '{}',
        isAcknowledged: false,
        purchaseState: status,
      ),
    ).single;

class TestStore extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  Completer<bool>? availability;
  int purchases = 0;
  int completed = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async =>
      availability == null ? true : await availability!.future;
  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      ProductDetails(
        id: ProProducts.weekly,
        title: 'Pro',
        description: 'Weekly',
        price: '₹99',
        rawPrice: 99,
        currencyCode: 'INR',
      ),
    ],
    notFoundIDs: [],
  );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    purchases++;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed++;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    updates.add([purchase(PurchaseStatus.restored)]);
  }
}

PurchaseDetails purchase(
  PurchaseStatus status, {
  String? id,
  IAPError? error,
}) =>
    PurchaseDetails(
        productID: id ?? ProProducts.weekly,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'test-token',
          source: 'test',
        ),
        transactionDate: '0',
        status: status,
      )
      ..error = error
      ..pendingCompletePurchase = true;

Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Instantiate before installing our platform double (singleton registers a store).
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  InAppPurchase.instance;
  debugDefaultTargetPlatformOverride = null;
  late TestStore store;
  late TestApi api;
  late ProviderContainer container;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    store = TestStore();
    api = TestApi();
    InAppPurchasePlatform.instance = store;
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(TestAuth.new),
        apiServiceProvider.overrideWithValue(api),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await store.updates.close();
    debugDefaultTargetPlatformOverride = null;
    InAppPurchasePlatformAddition.instance = null;
  });
  Future<BillingController> start() async {
    await container.read(authControllerProvider.future);
    final controller = container.read(billingControllerProvider.notifier);
    await flush();
    return controller;
  }

  test('approved purchase verifies before granting and finishing', () async {
    final controller = await start();
    await controller.buyPro();
    store.updates.add([purchase(PurchaseStatus.purchased)]);
    await flush();
    expect(container.read(isProProvider), isTrue);
    expect(api.verifications, 1);
    expect(store.completed, 1);
    expect(container.read(billingControllerProvider).busy, isFalse);
  });
  test('declined card permits a retry without granting Pro', () async {
    final controller = await start();
    await controller.buyPro();
    store.updates.add([
      purchase(
        PurchaseStatus.error,
        id: '',
        error: IAPError(
          source: 'store',
          code: 'declined',
          message: 'Payment declined',
        ),
      ),
    ]);
    await flush();
    expect(container.read(isProProvider), isFalse);
    expect(
      container.read(billingControllerProvider).error,
      contains('payment method'),
    );
    expect(store.completed, 0);
    await controller.buyPro();
    expect(store.purchases, 2);
  });
  test('canceling the sheet clears busy state without an error', () async {
    final controller = await start();
    await controller.buyPro();
    store.updates.add([purchase(PurchaseStatus.canceled, id: '')]);
    await flush();
    expect(container.read(billingControllerProvider).busy, isFalse);
    expect(container.read(billingControllerProvider).error, isNull);
    expect(api.verifications, 0);
  });
  for (final outcome in [PurchaseStatus.purchased, PurchaseStatus.error]) {
    test('slow payment remains free until $outcome', () async {
      final controller = await start();
      await controller.buyPro();
      store.updates.add([purchase(PurchaseStatus.pending)]);
      await flush();
      expect(container.read(isProProvider), isFalse);
      expect(
        container.read(billingControllerProvider).paymentAwaitingApproval,
        isTrue,
      );
      await controller.buyPro();
      expect(store.purchases, 1);
      expect(store.completed, 0);
      store.updates.add([purchase(outcome)]);
      await flush();
      expect(
        container.read(isProProvider),
        outcome == PurchaseStatus.purchased,
      );
      expect(container.read(billingControllerProvider).busy, isFalse);
      expect(
        container.read(billingControllerProvider).paymentAwaitingApproval,
        isFalse,
      );
    });
  }
  test(
    'verification outage offers Restore without finishing the transaction',
    () async {
      final controller = await start();
      api.failure = const AppException('Server unavailable', statusCode: 503);
      store.updates.add([purchase(PurchaseStatus.purchased)]);
      await flush();
      expect(container.read(isProProvider), isFalse);
      expect(
        container.read(billingControllerProvider).error,
        contains('Do not purchase again'),
      );
      expect(store.completed, 0);
      api.failure = null;
      expect(await controller.restorePurchases(), isTrue);
      expect(container.read(isProProvider), isTrue);
      expect(store.completed, 1);
    },
  );
  test(
    'slow store bootstrap cannot overwrite a resolved Pro session',
    () async {
      store.availability = Completer<bool>();
      final controller = await start();
      container
          .read(authControllerProvider.notifier)
          .setUser(user.copyWith(isPro: true));
      await flush();
      store.availability!.complete(true);
      await flush();
      expect(container.read(isProProvider), isTrue);
      await controller.buyPro();
      expect(store.purchases, 0);
    },
  );
  test('stale free limit response cannot restrict Pro', () async {
    await start();
    container
        .read(authControllerProvider.notifier)
        .setUser(user.copyWith(isPro: true));
    await container.read(playLimitStatusProvider.future);
    container
        .read(playLimitStatusProvider.notifier)
        .apply(
          const PlayLimitStatus(limited: true, isPro: false, viewsLeft: 0),
        );
    expect(container.read(playLimitStatusProvider).requireValue.isPro, isTrue);
    expect(
      container.read(playLimitStatusProvider).requireValue.limited,
      isFalse,
    );
  });
  test('Android owned pending purchase blocks a second checkout', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final addition =
        TestAndroidAddition()
          ..owned = [androidPurchase(PurchaseStateWrapper.pending)];
    InAppPurchasePlatformAddition.instance = addition;
    final controller = await start();
    await controller.buyPro();
    expect(store.purchases, 0);
    expect(
      container.read(billingControllerProvider).paymentAwaitingApproval,
      isTrue,
    );
    expect(container.read(isProProvider), isFalse);
    expect(api.verifications, 0);
    store.updates.add([androidPurchase(PurchaseStateWrapper.purchased)]);
    await flush();
    expect(container.read(isProProvider), isTrue);
    expect(store.completed, 1);
  });
}
