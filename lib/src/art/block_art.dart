import 'dart:math' as math;
import 'package:flutter/rendering.dart';

import '../meta/tower_theme.dart';
import 'tower_palette.dart';

/// Vector art for one tower floor. Pure drawing code, no assets.
///
/// [floor] 0 is the lobby (with a door); any other value is a regular floor
/// whose color and lit windows are picked deterministically from it.
class BlockArt {
  const BlockArt._();

  /// Height the floor art is designed for.
  static const double designHeight = 32;

  static void paint(
    Canvas canvas,
    Rect rect, {
    required TowerTheme theme,
    required int floor,
    double glow = 0,
    bool dimmed = false,
  }) {
    if (rect.width < 1 || rect.height < 1) return;
    final palette = TowerPalette.of(theme);
    final base = palette.floorColor(floor);
    if (glow > 0) _paintGlow(canvas, rect, glow, theme, base);
    canvas.save();
    final radius = Radius.circular(math.min(5, rect.width / 4));
    final rrect = RRect.fromRectAndRadius(rect, radius);
    canvas.clipRRect(rrect);
    switch (theme) {
      case TowerTheme.downtown:
        _downtown(canvas, rect, palette, base, floor);
      case TowerTheme.harbor:
        _harbor(canvas, rect, palette, base, floor);
      case TowerTheme.candy:
        _candy(canvas, rect, palette, base, floor);
      case TowerTheme.neon:
        _neon(canvas, rect, palette, base, floor);
    }
    if (dimmed) {
      canvas.drawRect(rect, Paint()..color = const Color(0x8C0B0E1A));
    }
    canvas.restore();
    if (theme != TowerTheme.neon) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = palette.trim.withValues(alpha: 0.55),
      );
    }
  }

  // ------------------------------------------------------------------ helpers

  static Color _shade(Color c, double amount) =>
      Color.lerp(c, const Color(0xFF000000), amount)!;

  static Color _tint(Color c, double amount) =>
      Color.lerp(c, const Color(0xFFFFFFFF), amount)!;

  /// Deterministic 0..1 hash for lit windows and decorations.
  static double _hash(int a, int b) {
    var h = a * 374761393 + b * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return (h & 0xFFFF) / 0xFFFF;
  }

  /// Evenly spaced slots of [slot] width across [span]; at least one.
  static List<double> _slots(
    double left,
    double span,
    double slot,
    double gap,
  ) {
    final count = math.max(1, ((span + gap) / (slot + gap)).floor());
    final used = count * slot + (count - 1) * gap;
    final start = left + (span - used) / 2;
    return <double>[for (var i = 0; i < count; i++) start + i * (slot + gap)];
  }

  static void _paintGlow(
    Canvas canvas,
    Rect rect,
    double glow,
    TowerTheme theme,
    Color base,
  ) {
    final color = theme == TowerTheme.neon ? base : const Color(0xFFFFF4C2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(4 + 4 * glow),
        const Radius.circular(9),
      ),
      Paint()
        ..color = color.withValues(alpha: 0.45 * glow.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  static void _verticalFill(Canvas canvas, Rect rect, Color top, Color bottom) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[top, bottom],
        ).createShader(rect),
    );
  }

  static void _door(
    Canvas canvas,
    Rect rect,
    TowerPalette palette,
    Color awning,
  ) {
    final doorW = math.min(16.0, rect.width * 0.3);
    final doorH = rect.height * 0.62;
    final door = Rect.fromLTWH(
      rect.center.dx - doorW / 2,
      rect.bottom - doorH,
      doorW,
      doorH,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        door,
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      ),
      Paint()..color = palette.door,
    );
    canvas.drawRect(
      Rect.fromLTWH(door.center.dx - 0.5, door.top + 2, 1, door.height - 2),
      Paint()..color = palette.glass.withValues(alpha: 0.5),
    );
    // Striped awning above the door.
    final aw = Rect.fromLTWH(door.left - 6, door.top - 5, door.width + 12, 5);
    canvas.drawRect(aw, Paint()..color = awning);
    final stripe = Paint()..color = const Color(0xCCFFFFFF);
    for (var x = aw.left; x < aw.right; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, aw.top, 3, aw.height), stripe);
    }
  }

  // ------------------------------------------------------------- downtown

  static void _downtown(
    Canvas canvas,
    Rect r,
    TowerPalette p,
    Color base,
    int floor,
  ) {
    _verticalFill(canvas, r, _tint(base, 0.12), _shade(base, 0.12));
    // Cornice along the top.
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 4),
      Paint()..color = _tint(base, 0.45),
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top + 4, r.width, 1.2),
      Paint()..color = _shade(base, 0.3),
    );
    // Pilasters.
    final pilaster = Paint()..color = _shade(base, 0.18);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + 5, 3, r.height), pilaster);
    canvas.drawRect(
      Rect.fromLTWH(r.right - 3, r.top + 5, 3, r.height),
      pilaster,
    );
    // Bottom shadow line.
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.bottom - 2.5, r.width, 2.5),
      Paint()..color = _shade(base, 0.35),
    );

    final winTop = r.top + 9;
    final winH = r.height - 15;
    if (floor <= 0) {
      _door(canvas, r, p, const Color(0xFFE63946));
      final side = (r.width - 34) / 2;
      if (side > 10) {
        for (final x in _slots(r.left + 4, side - 4, 9, 6)) {
          _glassWindow(canvas, Rect.fromLTWH(x, winTop, 9, winH), p, false);
        }
        for (final x in _slots(r.right - side, side - 4, 9, 6)) {
          _glassWindow(canvas, Rect.fromLTWH(x, winTop, 9, winH), p, false);
        }
      }
      return;
    }
    final slots = _slots(r.left + 5, r.width - 10, 9, 6);
    for (var i = 0; i < slots.length; i++) {
      final lit = _hash(floor, i) < 0.32;
      _glassWindow(canvas, Rect.fromLTWH(slots[i], winTop, 9, winH), p, lit);
    }
  }

  static void _glassWindow(Canvas canvas, Rect w, TowerPalette p, bool lit) {
    final rr = RRect.fromRectAndRadius(w, const Radius.circular(2));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: lit
              ? <Color>[p.glassLit, _shade(p.glassLit, 0.12)]
              : <Color>[_tint(p.glass, 0.3), _shade(p.glass, 0.15)],
        ).createShader(w),
    );
    // Glint.
    canvas.drawLine(
      Offset(w.left + 2, w.bottom - 4),
      Offset(w.right - 2, w.top + 3),
      Paint()
        ..color = const Color(0x8CFFFFFF)
        ..strokeWidth = 1.2,
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = p.trim.withValues(alpha: 0.6),
    );
    // Sill.
    canvas.drawRect(
      Rect.fromLTWH(w.left - 1, w.bottom, w.width + 2, 1.5),
      Paint()..color = const Color(0x99FFFFFF),
    );
  }

  // --------------------------------------------------------------- harbor

  static void _harbor(
    Canvas canvas,
    Rect r,
    TowerPalette p,
    Color base,
    int floor,
  ) {
    _verticalFill(canvas, r, _tint(base, 0.08), _shade(base, 0.14));
    // Planks.
    final seam = Paint()
      ..color = _shade(base, 0.32)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final y = r.top + r.height * i / 3;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), seam);
    }
    // Grain flecks.
    final grain = Paint()
      ..color = _shade(base, 0.2)
      ..strokeWidth = 1;
    for (var i = 0; i < r.width ~/ 14; i++) {
      final x = r.left + 6 + i * 14 + _hash(floor, i) * 6;
      final y = r.top + 4 + (_hash(i, floor) * 3).floor() * r.height / 3;
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), grain);
    }
    // Frame.
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = _shade(base, 0.38);
    canvas.drawRect(r.deflate(1.5), frame);
    // Metal corner plates with rivets.
    final plate = Paint()..color = const Color(0xFF5C6770);
    final rivet = Paint()..color = const Color(0xFFD9DEE2);
    for (final c in <Offset>[
      r.topLeft,
      Offset(r.right - 6, r.top),
      Offset(r.left, r.bottom - 6),
      Offset(r.right - 6, r.bottom - 6),
    ]) {
      canvas.drawRect(Rect.fromLTWH(c.dx, c.dy, 6, 6), plate);
      canvas.drawCircle(c + const Offset(3, 3), 1, rivet);
    }
    if (floor <= 0) {
      _door(canvas, r, p, const Color(0xFF2E86AB));
      return;
    }
    // Portholes.
    final cy = r.center.dy + 1;
    for (final x in _slots(r.left + 8, r.width - 16, 11, 7)) {
      final c = Offset(x + 5.5, cy);
      canvas.drawCircle(c, 5.5, Paint()..color = const Color(0xFFD4A84F));
      final lit = _hash(floor, x.round()) < 0.3;
      canvas.drawCircle(c, 3.8, Paint()..color = lit ? p.glassLit : p.glass);
      canvas.drawCircle(
        c + const Offset(-1.2, -1.2),
        1.2,
        Paint()..color = const Color(0xB3FFFFFF),
      );
    }
  }

  // ---------------------------------------------------------------- candy

  static void _candy(
    Canvas canvas,
    Rect r,
    TowerPalette p,
    Color base,
    int floor,
  ) {
    _verticalFill(canvas, r, _tint(base, 0.18), _shade(base, 0.06));
    // Sprinkles.
    const sprinkleColors = <Color>[
      Color(0xFFFFFFFF),
      Color(0xFFFF5D8F),
      Color(0xFF5DD9C1),
      Color(0xFFFFD23F),
    ];
    for (var i = 0; i < r.width ~/ 9; i++) {
      final x = r.left + 4 + _hash(floor, i) * (r.width - 8);
      final y = r.top + 11 + _hash(i, floor + 7) * (r.height - 15);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(_hash(i + 3, floor) * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-2, -0.7, 4, 1.4),
          const Radius.circular(1),
        ),
        Paint()..color = sprinkleColors[i % sprinkleColors.length],
      );
      canvas.restore();
    }
    if (floor <= 0) {
      _door(canvas, r, p, const Color(0xFFFF5D8F));
    } else {
      // Arched windows.
      for (final x in _slots(r.left + 6, r.width - 12, 9, 7)) {
        final w = Rect.fromLTWH(x, r.top + 12, 9, r.height - 17);
        final rr = RRect.fromRectAndCorners(
          w,
          topLeft: const Radius.circular(4.5),
          topRight: const Radius.circular(4.5),
          bottomLeft: const Radius.circular(1),
          bottomRight: const Radius.circular(1),
        );
        canvas.drawRRect(rr, Paint()..color = p.trim.withValues(alpha: 0.8));
        canvas.drawRRect(
          rr.deflate(1.4),
          Paint()
            ..color = _hash(floor, x.round()) < 0.35 ? p.glassLit : p.glass,
        );
      }
    }
    // Frosting band with drips.
    final frost = Paint()..color = const Color(0xFFFFFBF5);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 5), frost);
    var x = r.left;
    var i = 0;
    while (x < r.right) {
      final drip = 2.5 + _hash(floor + 11, i) * 4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, r.top + 3, 6, drip + 2),
          const Radius.circular(3),
        ),
        frost,
      );
      x += 8 + _hash(i, floor + 5) * 5;
      i += 1;
    }
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 1.5),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }

  // ----------------------------------------------------------------- neon

  static void _neon(
    Canvas canvas,
    Rect r,
    TowerPalette p,
    Color base,
    int floor,
  ) {
    _verticalFill(
      canvas,
      r,
      Color.lerp(const Color(0xFF231A4A), base, 0.18)!,
      const Color(0xFF0E0A22),
    );
    // Window bars.
    final barTop = r.top + 8;
    final barH = r.height - 14;
    final slots = _slots(r.left + 6, r.width - 12, 7, 5);
    for (var i = 0; i < slots.length; i++) {
      final lit = _hash(floor, i) < 0.55;
      final w = Rect.fromLTWH(slots[i], barTop, 7, barH);
      canvas.drawRect(
        w,
        Paint()..color = lit ? base.withValues(alpha: 0.55) : p.glass,
      );
      if (lit) {
        canvas.drawRect(
          Rect.fromLTWH(w.left, w.top, w.width, 2),
          Paint()..color = _tint(base, 0.6),
        );
      }
    }
    if (floor <= 0) {
      final door = Rect.fromLTWH(r.center.dx - 8, r.bottom - 18, 16, 18);
      canvas.drawRect(door, Paint()..color = const Color(0xFF07050F));
      canvas.drawRect(
        door,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFF4FD8),
      );
    }
    // Neon tubes along the top and bottom edges.
    for (final y in <double>[r.top + 1.5, r.bottom - 1.5]) {
      canvas.drawLine(
        Offset(r.left, y),
        Offset(r.right, y),
        Paint()
          ..color = base.withValues(alpha: 0.5)
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawLine(
        Offset(r.left, y),
        Offset(r.right, y),
        Paint()
          ..color = _tint(base, 0.5)
          ..strokeWidth = 1.4,
      );
    }
    canvas.drawRect(
      r.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = base.withValues(alpha: 0.7),
    );
  }
}

/// Small tower and skyline preview of a theme, used by the theme picker.
class ThemePreviewPainter extends CustomPainter {
  const ThemePreviewPainter({required this.theme, this.locked = false});

  final TowerTheme theme;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = TowerPalette.of(theme);
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    final night = theme == TowerTheme.neon;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night
              ? const <Color>[Color(0xFF0B0B2A), Color(0xFF3B1E6E)]
              : <Color>[
                  Color.lerp(
                    const Color(0xFF5DB8F0),
                    palette.skyTint,
                    palette.skyTintAmount,
                  )!,
                  Color.lerp(
                    const Color(0xFFCDEEFF),
                    palette.skyTint,
                    palette.skyTintAmount,
                  )!,
                ],
        ).createShader(rect),
    );
    final groundY = size.height * 0.84;
    // Skyline.
    final sky = Paint()..color = palette.skylineFar;
    for (var i = 0; i < 6; i++) {
      final w = size.width / 6;
      final h = size.height * (0.18 + BlockArt._hash(i, theme.index) * 0.22);
      canvas.drawRect(Rect.fromLTWH(i * w, groundY - h, w - 2, h), sky);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      Paint()..color = palette.ground,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, 3),
      Paint()..color = palette.groundTop,
    );
    final blockH = math.min(16.0, size.height * 0.13);
    final widths = <double>[0.62, 0.58, 0.58, 0.5, 0.46];
    final offsets = <double>[0, 0.02, -0.01, 0.02, 0.03];
    for (var i = 0; i < widths.length; i++) {
      final w = size.width * widths[i];
      final left = (size.width - w) / 2 + offsets[i] * size.width;
      // Blocks are designed 32 px tall; scale the whole floor down.
      final scale = blockH / BlockArt.designHeight;
      canvas.save();
      canvas.translate(left, groundY - (i + 1) * blockH);
      canvas.scale(scale);
      BlockArt.paint(
        canvas,
        Rect.fromLTWH(0, 0, w / scale, BlockArt.designHeight),
        theme: theme,
        floor: i,
      );
      canvas.restore();
    }
    if (locked) {
      canvas.drawRect(rect, Paint()..color = const Color(0xA6141828));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ThemePreviewPainter oldDelegate) =>
      oldDelegate.theme != theme || oldDelegate.locked != locked;
}
