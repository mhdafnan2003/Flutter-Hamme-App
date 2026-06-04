import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/interaction_type.dart';

final deferredInteractionTokenProvider = StateProvider<String?>((ref) => null);
final deferredShareCodeProvider = StateProvider<String?>((ref) => null);
final deferredInteractionTypeProvider = StateProvider<InteractionType?>((ref) => null);
final deferredInteractionErrorProvider = StateProvider<String?>((ref) => null);

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

class DeferredShareCodeController extends StateNotifier<String?> {
  DeferredShareCodeController() : super(null);

  void setShareCode(String code) {
    debugPrint('[DeferredInteraction] Share code set: $code');
    state = code;
  }

  void clearShareCode() {
    debugPrint('[DeferredInteraction] Share code cleared');
    state = null;
  }
}

class DeferredInteractionTypeController extends StateNotifier<InteractionType?> {
  DeferredInteractionTypeController() : super(null);

  void setType(InteractionType type) {
    debugPrint('[DeferredInteraction] Type set: ${type.name}');
    state = type;
  }

  void clearType() {
    debugPrint('[DeferredInteraction] Type cleared');
    state = null;
  }
}
