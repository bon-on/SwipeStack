import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../swipe_stack_controller.dart';
import '../swipe_stack_models.dart';

/// A piece cut off an imperfect drop, tumbling down.
class ChipFx {
  ChipFx({
    required this.segment,
    required this.floor,
    required this.start,
    required this.direction,
  });

  final BoxSegment segment;

  /// Stack index the chip was cut at (its starting height).
  final int floor;
  final double start;

  /// -1 falls to the left, 1 to the right.
  final double direction;
}

/// One landing: squash, dust and (for perfect drops) a flash.
class LandFx {
  LandFx({
    required this.floor,
    required this.start,
    required this.perfect,
    required this.seed,
  });

  final int floor;
  final double start;
  final bool perfect;
  final int seed;
}

/// Floating text such as "+1" or "Perfect!" above a floor.
class PopupFx {
  PopupFx({
    required this.text,
    required this.floor,
    required this.centerX,
    required this.start,
    required this.color,
    this.big = false,
  });

  final String text;
  final int floor;
  final double centerX;
  final double start;
  final Color color;
  final bool big;
}

/// A banner across the play field (perfect streaks, missions).
class BannerFx {
  BannerFx({
    required this.title,
    required this.subtitle,
    required this.start,
    required this.color,
    required this.serial,
  });

  final String title;
  final String subtitle;
  final double start;
  final Color color;
  final int serial;

  static const double duration = 1.5;
}

/// A piece of the tower toppling at game over.
class FallingPiece {
  FallingPiece({
    required this.segment,
    required this.floor,
    required this.delay,
    required this.spin,
    required this.drift,
  });

  final BoxSegment segment;
  final int floor;
  final double delay;
  final double spin;
  final double drift;
}

/// Game-over collapse: the failed box and the top floors fall away.
class CollapseFx {
  CollapseFx({
    required this.start,
    required this.fromFloor,
    required this.pieces,
  });

  final double start;

  /// Stack indices at or above this are drawn by the collapse, not the tower.
  final int fromFloor;
  final List<FallingPiece> pieces;
}

/// Visual effect state for the tower, driven by the screen's one ticker.
///
/// Rules never wait for anything here: the controller has already applied
/// every landing and failure; these effects only trail behind.
class TowerFx extends ChangeNotifier {
  /// Effect clock in seconds. Advanced only by [tick].
  double clock = 0;

  /// Smoothed camera height in floors (stack length).
  double cameraFloors = 1;

  final List<ChipFx> chips = <ChipFx>[];
  final List<LandFx> lands = <LandFx>[];
  final List<PopupFx> popups = <PopupFx>[];
  BannerFx? banner;
  CollapseFx? collapse;
  double _wobbleStart = -10;
  double _wobbleDir = 0;
  double _shakeStart = -10;
  double _shakeAmount = 0;
  int _seed = 1;
  int _bannerSerial = 0;

  static const double chipLife = 1.6;
  static const double landLife = 0.6;
  static const double popupLife = 0.9;
  static const double collapseLife = 2.2;

  /// Advances the clock and eases the camera toward [stackLength].
  void tick(double dt, int stackLength) {
    if (dt <= 0) return;
    final step = math.min(dt, 0.1);
    clock += step;
    final target = stackLength.toDouble();
    final diff = target - cameraFloors;
    if (diff.abs() < 0.002) {
      cameraFloors = target;
    } else {
      cameraFloors += diff * (1 - math.exp(-step * 9));
    }
    chips.removeWhere((c) => clock - c.start > chipLife);
    lands.removeWhere((l) => clock - l.start > landLife);
    popups.removeWhere((p) => clock - p.start > popupLife);
    final b = banner;
    if (b != null && clock - b.start > BannerFx.duration) banner = null;
    notifyListeners();
  }

  /// Clears every effect for a new run and snaps the camera to the ground.
  void reset(int stackLength) {
    chips.clear();
    lands.clear();
    popups.clear();
    banner = null;
    collapse = null;
    _wobbleStart = -10;
    _shakeStart = -10;
    cameraFloors = stackLength.toDouble();
    notifyListeners();
  }

  void onLanding(LandingInfo landing, {required int streak}) {
    lands.add(
      LandFx(
        floor: landing.floor,
        start: clock,
        perfect: landing.perfect,
        seed: _seed++,
      ),
    );
    for (final chip in landing.chips) {
      chips.add(
        ChipFx(
          segment: chip,
          floor: landing.floor,
          start: clock,
          direction: chip.centerX < landing.landed.centerX ? -1 : 1,
        ),
      );
    }
    popups.add(
      PopupFx(
        text: '+1',
        floor: landing.floor,
        centerX: landing.landed.right,
        start: clock,
        color: const Color(0xFFFFFFFF),
      ),
    );
    if (landing.perfect) {
      popups.add(
        PopupFx(
          text: 'Perfect!',
          floor: landing.floor,
          centerX: landing.landed.centerX,
          start: clock,
          color: const Color(0xFFFFE27A),
          big: true,
        ),
      );
      if (streak >= 2) {
        showBanner(
          'Perfect x$streak',
          streak >= SwipeStackController.perfectStreakForGrowth
              ? 'Tower grows wider!'
              : 'Keep it going',
          const Color(0xFFFFC857),
        );
      }
    } else {
      _wobbleStart = clock;
      _wobbleDir = landing.chips.isEmpty
          ? 1
          : (landing.chips.first.centerX < landing.landed.centerX ? -1 : 1);
    }
  }

  void showBanner(String title, String subtitle, Color color) {
    _bannerSerial += 1;
    banner = BannerFx(
      title: title,
      subtitle: subtitle,
      start: clock,
      color: color,
      serial: _bannerSerial,
    );
    notifyListeners();
  }

  /// Starts the game-over collapse from the controller's final state.
  void onCollapse(List<BoxSegment> stack, BoxSegment failed) {
    final top = stack.last;
    final dir = failed.centerX >= top.centerX ? 1.0 : -1.0;
    final count = math.min(4, stack.length - 1);
    final fromFloor = stack.length - count;
    final pieces = <FallingPiece>[
      FallingPiece(
        segment: failed,
        floor: stack.length,
        delay: 0,
        spin: dir * 3.2,
        drift: dir * 90,
      ),
    ];
    for (var i = stack.length - 1; i >= fromFloor; i--) {
      final depth = stack.length - i;
      pieces.add(
        FallingPiece(
          segment: stack[i],
          floor: i,
          delay: 0.12 + depth * 0.09,
          spin: dir * (1.2 + depth * 0.5) * (depth.isEven ? -0.6 : 1),
          drift: dir * (40 + depth * 25),
        ),
      );
    }
    collapse = CollapseFx(start: clock, fromFloor: fromFloor, pieces: pieces);
    _shakeStart = clock;
    _shakeAmount = 7;
    notifyListeners();
  }

  /// Horizontal sway in pixels for stack index [floor] of [length] floors.
  double wobbleFor(int floor, int length) {
    final t = clock - _wobbleStart;
    if (t < 0 || t > 0.9) return 0;
    final depth = length - 1 - floor;
    if (depth > 5) return 0;
    final weight = (6 - depth) / 6;
    return _wobbleDir * 3.2 * weight * math.exp(-t * 5) * math.sin(t * 24);
  }

  /// Screen shake offset.
  Offset get shake {
    final t = clock - _shakeStart;
    if (t < 0 || t > 0.45) return Offset.zero;
    final a = _shakeAmount * (1 - t / 0.45);
    return Offset(math.sin(t * 70) * a, math.cos(t * 55) * a * 0.6);
  }

  /// True while anything is still animating.
  bool get isActive =>
      chips.isNotEmpty ||
      lands.isNotEmpty ||
      popups.isNotEmpty ||
      banner != null ||
      (collapse != null && clock - collapse!.start < collapseLife);
}
