enum InteractionType {
  crush,
  friend,
  frenemy,
  ameny;

  String get label => switch (this) {
    InteractionType.crush => 'Crush',
    InteractionType.friend => 'Friend',
    InteractionType.frenemy => 'Frenemy',
    InteractionType.ameny => 'Frenemy',
  };
}
