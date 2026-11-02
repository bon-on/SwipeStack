import 'dart:math' as math;
import 'package:flutter/painting.dart';

import '../meta/tower_theme.dart';
import 'tower_palette.dart';

/// One sky look at a given tower height (in floors).
class _SkyStop {
  const _SkyStop(this.altitude, this.top, this.bottom);

  final double altitude;
  final Color top;
  final Color bottom;
}

/// Parallax sky, clouds, stars and the themed skyline behind the tower.
///
/// The sky goes from day (clouds, sun) through sunset and dusk to space
/// (stars, a ringed planet) as the tower grows. Everything is derived from
/// the camera height and a clock, so the painter holds no state.
class SkyScenery {
  const SkyScenery._();

  static const List<_SkyStop> _stops = <_SkyStop>[
    _SkyStop(0, Color(0xFF4FB0EE), Color(0xFFC4ECFF)),
    _SkyStop(16, Color(0xFF6A8FE2), Color(0xFFFFE0B0)),
    _SkyStop(28, Color(0xFF5049A8), Color(0xFFFF9F7A)),
    _SkyStop(40, Color(0xFF231C5A), Color(0xFFA2508F)),
    _SkyStop(54, Color(0xFF070A24), Color(0xFF221C50)),
  ];

  static double _smooth(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Sky colors (top, bottom) for [floors] of height in [theme].
  static (Color, Color) skyColors(TowerTheme theme, double floors) {
    final palette = TowerPalette.of(theme);
    final alt = floors + palette.altitudeOffset;
    var top = _stops.last.top;
    var bottom = _stops.last.bottom;
    for (var i = 0; i < _stops.length - 1; i++) {
      final a = _stops[i];
      final b = _stops[i + 1];
      if (alt <= b.altitude) {
        final t = _smooth(a.altitude, b.altitude, alt);
        top = Color.lerp(a.top, b.top, t)!;
        bottom = Color.lerp(a.bottom, b.bottom, t)!;
        break;
      }
    }
    if (palette.skyTintAmount > 0) {
      top = Color.lerp(top, palette.skyTint, palette.skyTintAmount)!;
      bottom = Color.lerp(bottom, palette.skyTint, palette.skyTintAmount)!;
    }
    return (top, bottom);
  }

  /// 0 in daylight, 1 in space.
  static double nightAmount(TowerTheme theme, double floors) =>
      _smooth(24, 50, floors + TowerPalette.of(theme).altitudeOffset);

  static double _hash(int a, int b) {
    var h = a * 374761393 + b * 668265263 + 1013904223;
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return (h & 0xFFFF) / 0xFFFF;
  }

  /// Paints everything behind the tower.
  ///
  /// [floors] is the camera height in floors, [scrollPx] how far the camera
  /// has risen in pixels, [groundY] the screen y of the ground line and
  /// [time] a clock in seconds for drifting clouds and twinkling stars.
  static void paint(
    Canvas canvas,
    Size size, {
    required TowerTheme theme,
    required double floors,
    required double scrollPx,
    required double groundY,
    required double time,
  }) {
    final palette = TowerPalette.of(theme);
    final rect = Offset.zero & size;
    final (top, bottom) = skyColors(theme, floors);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[top, bottom],
        ).createShader(rect),
    );
    final night = nightAmount(theme, floors);
    final alt = floors + palette.altitudeOffset;

    _paintStars(canvas, size, night, scrollPx, time);
    _paintPlanet(canvas, size, alt, theme);
    _paintSun(canvas, size, alt, scrollPx);
    _paintClouds(canvas, size, alt, bottom, scrollPx, time, far: true);
    _paintSkyline(canvas, size, palette, theme, groundY, scrollPx, night);
    _paintBirds(canvas, size, alt, scrollPx, time);
    _paintClouds(canvas, size, alt, bottom, scrollPx, time, far: false);
    _paintGround(canvas, size, palette, theme, groundY, time);
  }

  static void _paintStars(
    Canvas canvas,
    Size size,
    double night,
    double scrollPx,
    double time,
  ) {
    if (night <= 0.02) return;
    final paint = Paint();
    const count = 70;
    final tile = size.height + 40;
    for (var i = 0; i < count; i++) {
      final x = _hash(i, 1) * size.width;
      final y = (_hash(i, 2) * tile + scrollPx * 0.06) % tile - 20;
      final twinkle =
          0.55 + 0.45 * math.sin(time * (1.2 + _hash(i, 3) * 2) + i);
      final r = 0.6 + _hash(i, 4) * 1.3;
      paint.color = const Color(
        0xFFFFFFFF,
      ).withValues(alpha: (night * twinkle).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), r, paint);
      if (r > 1.7) {
        paint.color = paint.color.withValues(alpha: paint.color.a * 0.35);
        canvas.drawCircle(Offset(x, y), r * 2.4, paint);
      }
    }
  }

  static void _paintPlanet(
    Canvas canvas,
    Size size,
    double alt,
    TowerTheme theme,
  ) {
    final a = _smooth(46, 62, alt);
    if (a <= 0.01) return;
    final c = Offset(size.width * 0.22, size.height * 0.2);
    final r = math.min(size.width, size.height) * 0.07;
    final body = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFFFFC27A).withValues(alpha: a),
            const Color(0xFFB0507A).withValues(alpha: a),
          ],
        ).createShader(body),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 3.4, height: r * 0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFE6C4).withValues(alpha: 0.75 * a),
    );
    canvas.restore();
    // Moon-ish second body.
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.12),
      r * 0.35,
      Paint()..color = const Color(0xFFE6E9FF).withValues(alpha: 0.8 * a),
    );
  }

  static void _paintSun(Canvas canvas, Size size, double alt, double scrollPx) {
    // The sun sinks (relative to the camera) and turns orange as you climb.
    final set = _smooth(6, 40, alt);
    final a = 1 - _smooth(34, 44, alt);
    if (a <= 0.01) return;
    final c = Offset(size.width * 0.8, size.height * (0.16 + 0.62 * set));
    final r = math.min(size.width, size.height) * (0.06 + 0.02 * set);
    final color = Color.lerp(
      const Color(0xFFFFF3B0),
      const Color(0xFFFF8A4C),
      set,
    )!;
    canvas.drawCircle(
      c,
      r * 3,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.45 * a),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 3)),
    );
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: a));
  }

  static void _paintClouds(
    Canvas canvas,
    Size size,
    double alt,
    Color skyBottom,
    double scrollPx,
    double time, {
    required bool far,
  }) {
    final a = 1 - _smooth(30, 46, alt);
    if (a <= 0.01) return;
    final parallax = far ? 0.22 : 0.5;
    final count = far ? 6 : 5;
    final scale = far ? 0.65 : 1.0;
    final tile = size.height * 1.6;
    final color = Color.lerp(
      const Color(0xFFFFFFFF),
      skyBottom,
      far ? 0.35 : 0.18,
    )!;
    final paint = Paint()
      ..color = color.withValues(alpha: (far ? 0.7 : 0.92) * a);
    final shade = Paint()
      ..color = Color.lerp(
        color,
        const Color(0xFF7D8CC4),
        0.25,
      )!.withValues(alpha: (far ? 0.35 : 0.45) * a);
    for (var i = 0; i < count; i++) {
      final seed = i + (far ? 100 : 0);
      final speed = (far ? 5.0 : 10.0) + _hash(seed, 5) * 6;
      final span = size.width + 220;
      final x = (_hash(seed, 6) * span + time * speed) % span - 110;
      final y =
          (_hash(seed, 7) * tile + scrollPx * parallax) % tile -
          size.height * 0.3;
      if (y < -60 || y > size.height + 60) continue;
      final w = (60 + _hash(seed, 8) * 70) * scale;
      _cloud(canvas, Offset(x, y), w, paint, shade);
    }
  }

  static void _cloud(
    Canvas canvas,
    Offset c,
    double w,
    Paint paint,
    Paint shade,
  ) {
    final h = w * 0.32;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + Offset(0, h * 0.18),
          width: w,
          height: h * 0.9,
        ),
        Radius.circular(h),
      ),
      shade,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: w, height: h * 0.8),
        Radius.circular(h),
      ),
      paint,
    );
    canvas.drawCircle(c + Offset(-w * 0.18, -h * 0.25), h * 0.5, paint);
    canvas.drawCircle(c + Offset(w * 0.1, -h * 0.4), h * 0.62, paint);
    canvas.drawCircle(c + Offset(w * 0.3, -h * 0.12), h * 0.4, paint);
  }

  static void _paintBirds(
    Canvas canvas,
    Size size,
    double alt,
    double scrollPx,
    double time,
  ) {
    final a = 1 - _smooth(8, 16, alt);
    if (a <= 0.01) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF334466).withValues(alpha: 0.7 * a);
    for (var i = 0; i < 3; i++) {
      final span = size.width + 80;
      final x = (_hash(i, 21) * span + time * (14 + i * 3)) % span - 40;
      final y = size.height * (0.22 + 0.08 * i) + scrollPx * 0.3;
      final flap = math.sin(time * 6 + i * 2) * 3;
      final path = Path()
        ..moveTo(x - 6, y - flap)
        ..quadraticBezierTo(x - 3, y - 3, x, y)
        ..quadraticBezierTo(x + 3, y - 3, x + 6, y - flap);
      canvas.drawPath(path, paint);
    }
  }

  static void _paintSkyline(
    Canvas canvas,
    Size size,
    TowerPalette palette,
    TowerTheme theme,
    double groundY,
    double scrollPx,
    double night,
  ) {
    // Far layer rises slower than the ground (parallax).
    final farBase = groundY - scrollPx * 0.55;
    if (farBase > -40 && farBase - 160 < size.height) {
      _skylineRow(
        canvas,
        size,
        theme,
        farBase,
        palette.skylineFar,
        palette.skylineWindow,
        night,
        seed: 1,
        heightScale: 1.25,
        far: true,
      );
    }
    if (groundY - 140 < size.height) {
      _skylineRow(
        canvas,
        size,
        theme,
        groundY,
        palette.skylineNear,
        palette.skylineWindow,
        night,
        seed: 2,
        heightScale: 0.85,
        far: false,
      );
    }
  }

  static void _skylineRow(
    Canvas canvas,
    Size size,
    TowerTheme theme,
    double baseY,
    Color color,
    Color windowColor,
    double night, {
    required int seed,
    required double heightScale,
    required bool far,
  }) {
    final paint = Paint()..color = color;
    final win = Paint()
      ..color = windowColor.withValues(
        alpha: theme == TowerTheme.neon ? 0.8 : 0.25 + 0.55 * night,
      );
    switch (theme) {
      case TowerTheme.harbor:
        _harborSkyline(canvas, size, baseY, paint, win, seed, heightScale);
        return;
      case TowerTheme.candy:
        _candySkyline(canvas, size, baseY, paint, seed, heightScale, far);
        return;
      case TowerTheme.downtown:
      case TowerTheme.neon:
        break;
    }
    var x = -10.0;
    var i = 0;
    while (x < size.width + 10) {
      final w = 26 + _hash(i, seed) * 34;
      final h = (40 + _hash(i, seed + 9) * 90) * heightScale;
      final r = Rect.fromLTWH(x, baseY - h, w, h + 2);
      canvas.drawRect(r, paint);
      if (_hash(i, seed + 3) < 0.35) {
        // Antenna or stepped top.
        canvas.drawRect(Rect.fromLTWH(x + w / 2 - 1, r.top - 12, 2, 12), paint);
      } else if (_hash(i, seed + 4) < 0.5) {
        canvas.drawRect(Rect.fromLTWH(x + 5, r.top - 8, w - 10, 8), paint);
      }
      // Windows.
      for (var wy = r.top + 7; wy < baseY - 8; wy += 9) {
        for (var wx = x + 5; wx < x + w - 6; wx += 7) {
          if (_hash(wx.round() + i, wy.round()) < 0.42) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 3, 4), win);
          }
        }
      }
      if (theme == TowerTheme.neon && !far && _hash(i, 77) < 0.4) {
        canvas.drawRect(
          Rect.fromLTWH(x + 3, r.top + 4, w - 6, 3),
          Paint()
            ..color =
                (i.isEven ? const Color(0xFFFF4FD8) : const Color(0xFF29F0FF))
                    .withValues(alpha: 0.85),
        );
      }
      x += w + 3 + _hash(i, seed + 5) * 6;
      i += 1;
    }
  }

  static void _harborSkyline(
    Canvas canvas,
    Size size,
    double baseY,
    Paint paint,
    Paint win,
    int seed,
    double heightScale,
  ) {
    var x = -10.0;
    var i = 0;
    while (x < size.width + 10) {
      final kind = _hash(i, seed + 2);
      if (kind < 0.3) {
        // Crane.
        final h = (110 + _hash(i, seed) * 40) * heightScale;
        canvas.drawRect(Rect.fromLTWH(x + 8, baseY - h, 5, h), paint);
        canvas.drawRect(Rect.fromLTWH(x - 6, baseY - h, 46, 4), paint);
        canvas.drawLine(
          Offset(x + 34, baseY - h + 4),
          Offset(x + 34, baseY - h + 30),
          Paint()
            ..color = paint.color
            ..strokeWidth = 1,
        );
        canvas.drawRect(Rect.fromLTWH(x + 30, baseY - h + 30, 8, 6), paint);
        x += 50;
      } else {
        // Warehouse with a pitched roof.
        final w = 40 + _hash(i, seed + 6) * 30;
        final h = (30 + _hash(i, seed + 7) * 34) * heightScale;
        final path = Path()
          ..moveTo(x, baseY + 2)
          ..lineTo(x, baseY - h)
          ..lineTo(x + w / 2, baseY - h - 12)
          ..lineTo(x + w, baseY - h)
          ..lineTo(x + w, baseY + 2)
          ..close();
        canvas.drawPath(path, paint);
        for (var wx = x + 6; wx < x + w - 8; wx += 10) {
          canvas.drawRect(Rect.fromLTWH(wx, baseY - h + 8, 4, 4), win);
        }
        x += w + 4;
      }
      i += 1;
    }
  }

  static void _candySkyline(
    Canvas canvas,
    Size size,
    double baseY,
    Paint paint,
    int seed,
    double heightScale,
    bool far,
  ) {
    // Rolling cream hills.
    final hills = Path()..moveTo(-10, baseY + 2);
    for (var x = -10.0; x <= size.width + 40; x += 40) {
      final h = (24 + _hash(x.round(), seed) * 30) * heightScale;
      hills.quadraticBezierTo(x + 20, baseY - h * 1.6, x + 40, baseY - h * 0.4);
    }
    hills
      ..lineTo(size.width + 40, baseY + 2)
      ..close();
    canvas.drawPath(hills, paint);
    if (far) return;
    // Lollipop trees.
    const swirl = <Color>[
      Color(0xFFFF5D8F),
      Color(0xFF5DD9C1),
      Color(0xFFFFD23F),
    ];
    for (var i = 0; i < 7; i++) {
      final x = (i + 0.5) * size.width / 7 + (_hash(i, 30) - 0.5) * 20;
      final h = 34 + _hash(i, 31) * 30;
      canvas.drawRect(
        Rect.fromLTWH(x - 1.2, baseY - h, 2.4, h),
        Paint()..color = const Color(0xFFFFF6FB),
      );
      final c = Offset(x, baseY - h);
      canvas.drawCircle(c, 9, Paint()..color = swirl[i % swirl.length]);
      canvas.drawCircle(
        c,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xCCFFFFFF),
      );
    }
  }

  static void _paintGround(
    Canvas canvas,
    Size size,
    TowerPalette palette,
    TowerTheme theme,
    double groundY,
    double time,
  ) {
    if (groundY > size.height) return;
    final ground = Rect.fromLTRB(0, groundY, size.width, size.height + 2);
    canvas.drawRect(ground, Paint()..color = palette.ground);
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, 6),
      Paint()..color = palette.groundTop,
    );
    final detail = Paint()..color = palette.groundDetail.withValues(alpha: 0.7);
    switch (theme) {
      case TowerTheme.downtown:
        // Road markings.
        for (var x = 8.0; x < size.width; x += 36) {
          canvas.drawRect(Rect.fromLTWH(x, groundY + 22, 18, 3), detail);
        }
        canvas.drawRect(
          Rect.fromLTWH(0, groundY + 6, size.width, 6),
          Paint()..color = const Color(0xFFB8BEC6),
        );
      case TowerTheme.harbor:
        // Pier boards and waves.
        canvas.drawRect(
          Rect.fromLTWH(0, groundY, size.width, 10),
          Paint()..color = palette.groundTop,
        );
        final board = Paint()..color = const Color(0xFF8A6A43);
        for (var x = 0.0; x < size.width; x += 14) {
          canvas.drawRect(Rect.fromLTWH(x, groundY, 1, 10), board);
        }
        final wave = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = palette.groundDetail.withValues(alpha: 0.6);
        for (var row = 0; row < 3; row++) {
          final y = groundY + 20 + row * 12;
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x <= size.width; x += 8) {
            path.lineTo(x, y + math.sin(x / 9 + time * 1.6 + row) * 2);
          }
          canvas.drawPath(path, wave);
        }
      case TowerTheme.candy:
        final drip = Paint()..color = palette.groundTop;
        for (var x = 0.0; x < size.width; x += 18) {
          canvas.drawCircle(Offset(x + 9, groundY + 6), 6, drip);
        }
        for (var i = 0; i < 24; i++) {
          canvas.drawCircle(
            Offset(_hash(i, 40) * size.width, groundY + 16 + _hash(i, 41) * 30),
            1.6,
            detail,
          );
        }
      case TowerTheme.neon:
        final line = Paint()
          ..color = palette.groundDetail.withValues(alpha: 0.75)
          ..strokeWidth = 1.5;
        canvas.drawLine(
          Offset(0, groundY + 1),
          Offset(size.width, groundY + 1),
          Paint()
            ..color = const Color(0xFF29F0FF)
            ..strokeWidth = 2,
        );
        // Perspective grid.
        for (var i = 0; i < 4; i++) {
          final y = groundY + 10 + i * i * 6.0;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        for (var i = -6; i <= 6; i++) {
          final cx = size.width / 2;
          canvas.drawLine(
            Offset(cx + i * 30, groundY + 6),
            Offset(cx + i * 90, size.height + 2),
            line,
          );
        }
    }
  }
}
