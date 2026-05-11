import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final deferredInteractionTokenProvider = StateProvider<String?>((ref) => null);

class DeferredInteractionController extends StateNotifier<String?> {
  DeferredInteractionController() : super(null);

  void setToken(String token) {
    debugPrint('[DeferredInteraction] Token set: $token');
    state = token;
  }

  void clearToken() {
    debugPrint('[DeferredInteraction] Token cleared');
    state = null;
  }
}
