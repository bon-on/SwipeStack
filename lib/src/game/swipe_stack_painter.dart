import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/block_art.dart';
import '../art/sky_scenery.dart';
import '../meta/tower_theme.dart';
import 'swipe_stack_controller.dart';
import 'swipe_stack_models.dart';
import 'ui/tower_fx.dart';

/// Paints the sky, the tower, the moving floor and every effect.
///
/// Repaints on controller and effect changes only; nothing here rebuilds
/// widgets.
class SwipeStackPainter extends CustomPainter {
  SwipeStackPainter({
    required this.controller,
    required this.fx,
    this.theme = TowerTheme.downtown,
  }) : super(repaint: Listenable.merge(<Listenable>[controller, fx]));

  final SwipeStackController controller;
  final TowerFx fx;
  final TowerTheme theme;

  static const double boxHeight = BlockArt.designHeight;
  static const double _movingTopFactor = 0.08;
  static const double _cameraGap = 88;

  /// Top width below which the danger pulse shows (a quarter of the start).
  static const double dangerWidth = SwipeStackController.baseWidth * 0.25;

  @override
  void paint(Canvas canvas, Size size) {
    final clip = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(24),
    );
    canvas.save();
    canvas.clipRRect(clip);
    final shake = fx.shake;
    canvas.translate(shake.dx, shake.dy);

    final stacked = controller.stackedBoxes;
    final metrics = StackMetrics.forSize(size, cameraFloors: fx.cameraFloors);
    final floorTop = metrics.floorTop;
    double floorY(int index) => floorTop - (index + 1) * boxHeight;

    SkyScenery.paint(
      canvas,
      size,
      theme: theme,
      floors: fx.cameraFloors,
      scrollPx: metrics.cameraOffset,
      groundY: floorTop,
      time: fx.clock,
    );

    _paintMarkers(canvas, size, floorY, stacked.length);

    final collapse = fx.collapse;
    final hiddenFrom = collapse?.fromFloor ?? stacked.length;
    final target = stacked.last;
    if (!controller.isGameOver) {
      _paintLandingGuide(canvas, size, target, floorY(stacked.length));
    }

    // Tower: only floors on screen are drawn.
    for (var index = 0; index < stacked.length && index < hiddenFrom; index++) {
      final y = floorY(index);
      if (y > size.height + boxHeight || y < -boxHeight * 2) continue;
      final box = stacked[index];
      var rect = Rect.fromLTWH(
        box.left * size.width + fx.wobbleFor(index, stacked.length),
        y,
        box.widthFactor * size.width,
        boxHeight,
      );
      var glow = 0.0;
      for (final land in fx.lands) {
        if (land.floor != index) continue;
        final t = fx.clock - land.start;
        final squash = 0.16 * math.max(0.0, 1 - t / 0.2);
        rect = Rect.fromLTRB(
          rect.left - rect.width * squash * 0.25,
          rect.bottom - boxHeight * (1 - squash),
          rect.right + rect.width * squash * 0.25,
          rect.bottom,
        );
        if (land.perfect) glow = math.max(0, 1 - t / 0.5);
      }
      BlockArt.paint(canvas, rect, theme: theme, floor: index, glow: glow);
    }

    _paintLandEffects(canvas, size, floorY);
    _paintChips(canvas, size, floorY);

    // Moving floor.
    final moving = controller.movingBox;
    final hideMoving = controller.isGameOver && collapse != null;
    if (!hideMoving) {
      final dropProgress = Curves.easeInCubic.transform(
        controller.dropProgress,
      );
      final restY = size.height * _movingTopFactor;
      final movingY = restY + (floorY(stacked.length) - restY) * dropProgress;
      _paintDropShadow(canvas, size, moving, movingY, dropProgress);
      final stretch = controller.isDropping
          ? 1 + (1 - dropProgress) * 0.24
          : 1.0;
      final h = boxHeight * stretch;
      final aligned =
          !controller.isGameOver &&
          !controller.isDropping &&
          controller.isPerfectAligned;
      BlockArt.paint(
        canvas,
        Rect.fromLTWH(
          moving.left * size.width,
          movingY - (h - boxHeight) / 2,
          moving.widthFactor * size.width,
          h,
        ),
        theme: theme,
        floor: stacked.length,
        glow: aligned ? 0.6 + 0.4 * math.sin(fx.clock * 10) : 0,
        dimmed: controller.isGameOver,
      );
    }

    if (collapse != null) _paintCollapse(canvas, size, collapse, floorY);
    _paintPopups(canvas, size, floorY);
    canvas.restore();

    _paintDanger(canvas, size, clip, target.widthFactor);
  }

  // ------------------------------------------------------------------ parts

  void _paintMarkers(
    Canvas canvas,
    Size size,
    double Function(int) floorY,
    int length,
  ) {
    // Height ticks every 10 floors (floor n's top is the n-th stack top).
    final first = math.max(10, ((fx.cameraFloors - 20) / 10).floor() * 10);
    for (var n = first; n <= fx.cameraFloors + 12; n += 10) {
      final y = floorY(n);
      if (y < -10 || y > size.height) continue;
      canvas.drawLine(
        Offset(0, y),
        Offset(14, y),
        Paint()
          ..color = const Color(0x99FFFFFF)
          ..strokeWidth = 2,
      );
      _text(
        canvas,
        '${n}F',
        Offset(18, y - 7),
        const TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    // Best height line: the record this run started with, so the player
    // sees the tower pass it.
    final best = controller.runStartBest;
    if (best <= 0) return;
    final y = floorY(best);
    if (y < -10 || y > size.height) return;
    final dash = Paint()
      ..color = const Color(0xE6FFC857)
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, y), Offset(x + 7, y), dash);
    }
    final label = Rect.fromLTWH(size.width - 70, y - 20, 62, 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, const Radius.circular(9)),
      Paint()..color = const Color(0xFFFFC857),
    );
    _text(
      canvas,
      'BEST $best',
      Offset(label.left + 8, label.top + 3),
      const TextStyle(
        color: Color(0xFF3A2A00),
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: 54,
    );
  }

  void _paintLandingGuide(
    Canvas canvas,
    Size size,
    BoxSegment target,
    double y,
  ) {
    final ok =
        controller.projectedOverlapRatio >=
        SwipeStackController.successThreshold;
    final color = ok ? const Color(0xFF6EE7B7) : const Color(0xFFFF6B6B);
    final rect = Rect.fromLTWH(
      target.left * size.width,
      y + boxHeight - 5,
      target.widthFactor * size.width,
      5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = color.withValues(alpha: 0.75),
    );
    // Faint column showing where the floor will land.
    final column = Rect.fromLTWH(
      target.left * size.width,
      size.height * _movingTopFactor + boxHeight,
      target.widthFactor * size.width,
      math.max(0, y + boxHeight - size.height * _movingTopFactor - boxHeight),
    );
    canvas.drawRect(
      column,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.16),
          ],
        ).createShader(column),
    );
  }

  void _paintDropShadow(
    Canvas canvas,
    Size size,
    BoxSegment box,
    double top,
    double dropProgress,
  ) {
    if (!controller.isDropping) return;
    final rect = Rect.fromLTWH(
      box.left * size.width,
      top + 10,
      box.widthFactor * size.width,
      boxHeight + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..color = const Color(
          0xFF000000,
        ).withValues(alpha: (0.14 + dropProgress * 0.12).clamp(0.0, 0.3))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _paintLandEffects(
    Canvas canvas,
    Size size,
    double Function(int) floorY,
  ) {
    final stacked = controller.stackedBoxes;
    for (final land in fx.lands) {
      if (land.floor >= stacked.length) continue;
      final box = stacked[land.floor];
      final t = fx.clock - land.start;
      final rect = Rect.fromLTWH(
        box.left * size.width,
        floorY(land.floor),
        box.widthFactor * size.width,
        boxHeight,
      );
      if (land.perfect) {
        // Expanding ring.
        final k = (t / 0.5).clamp(0.0, 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.inflate(4 + 26 * k),
            Radius.circular(8 + 10 * k),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - k) + 0.5
            ..color = const Color(0xFFFFF4C2).withValues(alpha: 1 - k),
        );
        // Sparkles.
        final rng = math.Random(land.seed);
        for (var i = 0; i < 10; i++) {
          final angle = rng.nextDouble() * math.pi * 2;
          final speed = 60 + rng.nextDouble() * 80;
          final p =
              rect.center +
              Offset(math.cos(angle), math.sin(angle) * 0.6) * speed * t;
          _star(
            canvas,
            p,
            3.5 * (1 - k),
            const Color(0xFFFFE27A).withValues(alpha: 1 - k),
          );
        }
      }
      // Dust puffs at both bottom corners.
      final k = (t / TowerFx.landLife).clamp(0.0, 1.0);
      final dust = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55 * (1 - k));
      final rng = math.Random(land.seed * 31);
      for (var i = 0; i < 6; i++) {
        final side = i.isEven ? -1.0 : 1.0;
        final origin = side < 0 ? rect.bottomLeft : rect.bottomRight;
        final vx = side * (20 + rng.nextDouble() * 40);
        final vy = -10 - rng.nextDouble() * 25;
        canvas.drawCircle(
          origin + Offset(vx * t, vy * t + 30 * t * t),
          2 + 5 * k,
          dust,
        );
      }
    }
  }

  void _paintChips(Canvas canvas, Size size, double Function(int) floorY) {
    for (final chip in fx.chips) {
      final t = fx.clock - chip.start;
      final w = chip.segment.widthFactor * size.width;
      final x = chip.segment.left * size.width + chip.direction * 50 * t;
      final y = floorY(chip.floor) - 40 * t + 0.5 * 1400 * t * t;
      if (y > size.height + 40) continue;
      canvas.save();
      canvas.translate(x + w / 2, y + boxHeight / 2);
      canvas.rotate(chip.direction * 3.5 * t);
      final alpha = (1 - t / TowerFx.chipLife).clamp(0.0, 1.0);
      canvas.saveLayer(
        Rect.fromCenter(center: Offset.zero, width: w + 40, height: 80),
        Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
      );
      BlockArt.paint(
        canvas,
        Rect.fromLTWH(-w / 2, -boxHeight / 2, w, boxHeight),
        theme: theme,
        floor: chip.floor,
      );
      canvas.restore();
      canvas.restore();
    }
  }

  void _paintCollapse(
    Canvas canvas,
    Size size,
    CollapseFx collapse,
    double Function(int) floorY,
  ) {
    final t0 = fx.clock - collapse.start;
    for (final piece in collapse.pieces) {
      final t = math.max(0.0, t0 - piece.delay);
      final w = piece.segment.widthFactor * size.width;
      final x = piece.segment.left * size.width + piece.drift * t;
      final y = floorY(piece.floor) + 0.5 * 1500 * t * t;
      if (y > size.height + 80) continue;
      canvas.save();
      canvas.translate(x + w / 2, y + boxHeight / 2);
      canvas.rotate(piece.spin * t);
      BlockArt.paint(
        canvas,
        Rect.fromLTWH(-w / 2, -boxHeight / 2, w, boxHeight),
        theme: theme,
        floor: piece.floor,
        dimmed: t > 0,
      );
      canvas.restore();
    }
  }

  void _paintPopups(Canvas canvas, Size size, double Function(int) floorY) {
    for (final popup in fx.popups) {
      final t = fx.clock - popup.start;
      final k = (t / TowerFx.popupLife).clamp(0.0, 1.0);
      final rise = 46 * Curves.easeOut.transform(k);
      final scale = popup.big ? 1 + 0.3 * math.max(0, 1 - t / 0.15) : 1.0;
      final style = TextStyle(
        color: popup.color.withValues(alpha: 1 - k * k),
        fontSize: (popup.big ? 22 : 16) * scale,
        fontWeight: FontWeight.w900,
        shadows: const <Shadow>[
          Shadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      );
      final painter = TextPainter(
        text: TextSpan(text: popup.text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      var x = popup.centerX * size.width - painter.width / 2;
      if (!popup.big) x = popup.centerX * size.width + 6;
      x = x.clamp(4.0, math.max(4.0, size.width - painter.width - 4));
      final y = floorY(popup.floor) - (popup.big ? 34 : 8) - rise;
      painter.paint(canvas, Offset(x, y));
    }
  }

  void _paintDanger(Canvas canvas, Size size, RRect clip, double topWidth) {
    if (controller.isGameOver || topWidth >= dangerWidth) return;
    final pulse = 0.5 + 0.5 * math.sin(fx.clock * 7);
    canvas.drawRRect(
      clip.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xFFFF4D4D).withValues(alpha: 0.25 + 0.4 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  static void _star(Canvas canvas, Offset c, double r, Color color) {
    if (r <= 0.2) return;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.4;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  static void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    double maxWidth = 120,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant SwipeStackPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.fx != fx ||
        oldDelegate.theme != theme;
  }
}

/// Camera placement: keeps the top of the tower a fixed gap below the
/// moving floor once the tower is tall enough.
class StackMetrics {
  const StackMetrics({required this.floorTop, required this.cameraOffset});

  /// Screen y of the ground line.
  final double floorTop;

  /// How far the camera has risen, in pixels.
  final double cameraOffset;

  static StackMetrics forSize(Size size, {required double cameraFloors}) {
    final baseFloorTop = size.height * 0.9;
    final naturalTop =
        baseFloorTop - cameraFloors * SwipeStackPainter.boxHeight;
    final desiredTop =
        size.height * SwipeStackPainter._movingTopFactor +
        SwipeStackPainter._cameraGap;
    final offset = naturalTop < desiredTop ? desiredTop - naturalTop : 0.0;
    return StackMetrics(floorTop: baseFloorTop + offset, cameraOffset: offset);
  }
}
