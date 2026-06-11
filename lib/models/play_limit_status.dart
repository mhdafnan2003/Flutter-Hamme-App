class PlayLimitStatus {
  const PlayLimitStatus({
    required this.limited,
    required this.isPro,
    this.viewsLeft,
    this.resetAt,
    this.maxCards,
    this.cooldownMinutes,
  });

  final bool limited;
  final bool isPro;
  final int? viewsLeft;
  final DateTime? resetAt;
  final int? maxCards;
  final int? cooldownMinutes;

  factory PlayLimitStatus.fromJson(Map<String, dynamic> json) {
    return PlayLimitStatus(
      limited: json['limited'] as bool? ?? false,
      isPro: json['isPro'] as bool? ?? false,
      viewsLeft: (json['viewsLeft'] as num?)?.toInt(),
      resetAt: json['resetAt'] != null
          ? DateTime.tryParse(json['resetAt'] as String)
          : null,
      maxCards: (json['maxCards'] as num?)?.toInt(),
      cooldownMinutes: (json['cooldownMinutes'] as num?)?.toInt(),
    );
  }

  static const PlayLimitStatus unrestricted = PlayLimitStatus(
    limited: false,
    isPro: true,
  );
}
