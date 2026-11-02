/// Cosmetic block and skyline themes, unlocked by player level.
/// Themes never change the stacking rules.
enum TowerTheme {
  downtown(requiredLevel: 1, label: 'Downtown'),
  harbor(requiredLevel: 3, label: 'Harbor'),
  candy(requiredLevel: 6, label: 'Candy'),
  neon(requiredLevel: 10, label: 'Neon');

  const TowerTheme({required this.requiredLevel, required this.label});

  /// Player level at which the theme becomes selectable.
  final int requiredLevel;

  /// Short English name shown in the UI.
  final String label;

  /// Parses a stored theme name; unknown values fall back to [downtown].
  static TowerTheme fromName(String? name) {
    for (final theme in values) {
      if (theme.name == name) return theme;
    }
    return downtown;
  }
}
