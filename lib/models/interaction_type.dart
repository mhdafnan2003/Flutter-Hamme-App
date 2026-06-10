enum InteractionType {
  crush,
  friend,
  frenemy;

  String get label => switch (this) {
    InteractionType.crush => 'Crush',
    InteractionType.friend => 'Friend',
    InteractionType.frenemy => 'Frenemy',
  };
}
