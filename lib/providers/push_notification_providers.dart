import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/push_notification_service.dart';
import 'api_providers.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(ref.watch(apiServiceProvider));
});
