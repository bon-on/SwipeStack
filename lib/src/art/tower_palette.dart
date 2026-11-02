import 'dart:ui';

import '../meta/tower_theme.dart';

/// Colors for one [TowerTheme]: blocks, ground and skyline.
class TowerPalette {
  const TowerPalette({
    required this.floors,
    required this.lobby,
    required this.trim,
    required this.glass,
    required this.glassLit,
    required this.door,
    required this.groundTop,
    required this.ground,
    required this.groundDetail,
    required this.skylineNear,
    required this.skylineFar,
    required this.skylineWindow,
    required this.skyTint,
    required this.skyTintAmount,
    required this.altitudeOffset,
    required this.accent,
  });

  /// Wall colors, cycled by floor index (floor 1 uses [floors][0]).
  final List<Color> floors;

  /// Ground floor (lobby) wall color.
  final Color lobby;

  /// Ledges, frames and outlines.
  final Color trim;
  final Color glass;
  final Color glassLit;
  final Color door;

  final Color groundTop;
  final Color ground;
  final Color groundDetail;
  final Color skylineNear;
  final Color skylineFar;
  final Color skylineWindow;

  /// Sky colors are blended toward [skyTint] by [skyTintAmount].
  final Color skyTint;
  final double skyTintAmount;

  /// Added to the tower height before choosing the sky (Neon starts at dusk).
  final double altitudeOffset;

  /// Highlight color used by UI elements that show this theme.
  final Color accent;

  Color floorColor(int floor) =>
      floor <= 0 ? lobby : floors[(floor - 1) % floors.length];

  static TowerPalette of(TowerTheme theme) {
    switch (theme) {
      case TowerTheme.downtown:
        return downtown;
      case TowerTheme.harbor:
        return harbor;
      case TowerTheme.candy:
        return candy;
      case TowerTheme.neon:
        return neon;
    }
  }

  static const TowerPalette downtown = TowerPalette(
    floors: <Color>[
      Color(0xFFF2A65A),
      Color(0xFFE76F51),
      Color(0xFF5FA8D3),
      Color(0xFFF4D35E),
      Color(0xFF7BC47F),
      Color(0xFFB088F9),
    ],
    lobby: Color(0xFF8D99AE),
    trim: Color(0xFF3D405B),
    glass: Color(0xFFBDE4F4),
    glassLit: Color(0xFFFFE8A3),
    door: Color(0xFF3D405B),
    groundTop: Color(0xFF7CC66E),
    ground: Color(0xFF55606E),
    groundDetail: Color(0xFFF4F1DE),
    skylineNear: Color(0xFF6B7FA8),
    skylineFar: Color(0xFF9CB3D9),
    skylineWindow: Color(0xFFE8F1FF),
    skyTint: Color(0xFFFFFFFF),
    skyTintAmount: 0,
    altitudeOffset: 0,
    accent: Color(0xFFFFB347),
  );

  static const TowerPalette harbor = TowerPalette(
    floors: <Color>[
      Color(0xFFC8553D),
      Color(0xFF2E86AB),
      Color(0xFFD9A441),
      Color(0xFF4F9D69),
      Color(0xFFE9E3D5),
      Color(0xFF6C5B7B),
    ],
    lobby: Color(0xFF8B5E3C),
    trim: Color(0xFF4A3426),
    glass: Color(0xFFA9D6E5),
    glassLit: Color(0xFFFFE29A),
    door: Color(0xFF4A3426),
    groundTop: Color(0xFFB08B5A),
    ground: Color(0xFF2F6690),
    groundDetail: Color(0xFFBEE3F8),
    skylineNear: Color(0xFF3A6F8F),
    skylineFar: Color(0xFF86AFC7),
    skylineWindow: Color(0xFFFFD27A),
    skyTint: Color(0xFFD7F2F6),
    skyTintAmount: 0.15,
    altitudeOffset: 4,
    accent: Color(0xFF4FC3F7),
  );

  static const TowerPalette candy = TowerPalette(
    floors: <Color>[
      Color(0xFFFF8FB1),
      Color(0xFF8EE3C8),
      Color(0xFFFFE07A),
      Color(0xFFB9A7FF),
      Color(0xFFFFB38A),
      Color(0xFF8FD3FF),
    ],
    lobby: Color(0xFFA9746E),
    trim: Color(0xFF7A4B47),
    glass: Color(0xFFFFF4E6),
    glassLit: Color(0xFFFFF1A8),
    door: Color(0xFF6D3B35),
    groundTop: Color(0xFFFFC6DD),
    ground: Color(0xFFF49AC2),
    groundDetail: Color(0xFFFFFFFF),
    skylineNear: Color(0xFFE38FB7),
    skylineFar: Color(0xFFF7C1DA),
    skylineWindow: Color(0xFFFFF6FB),
    skyTint: Color(0xFFFFC9E3),
    skyTintAmount: 0.28,
    altitudeOffset: 0,
    accent: Color(0xFFFF7EB6),
  );

  static const TowerPalette neon = TowerPalette(
    floors: <Color>[
      Color(0xFF29F0FF),
      Color(0xFFFF4FD8),
      Color(0xFFB6FF4F),
      Color(0xFFFFA63D),
      Color(0xFF9D7BFF),
      Color(0xFFFFF15C),
    ],
    lobby: Color(0xFF29F0FF),
    trim: Color(0xFF0D0B1E),
    glass: Color(0xFF221B44),
    glassLit: Color(0xFFFFFFFF),
    door: Color(0xFF0D0B1E),
    groundTop: Color(0xFF3A2D6B),
    ground: Color(0xFF120E26),
    groundDetail: Color(0xFFFF4FD8),
    skylineNear: Color(0xFF1C1640),
    skylineFar: Color(0xFF2D2560),
    skylineWindow: Color(0xFF29F0FF),
    skyTint: Color(0xFF3B1E6E),
    skyTintAmount: 0.2,
    altitudeOffset: 44,
    accent: Color(0xFF29F0FF),
  );
}
