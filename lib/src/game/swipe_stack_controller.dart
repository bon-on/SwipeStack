import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../persistence/best_stack_store.dart';
import 'swipe_stack_models.dart';

/// What happened on the latest successful landing, for visual effects only.
class LandingInfo {
  const LandingInfo({
    required this.serial,
    required this.floor,
    required this.perfect,
    required this.landed,
    required this.chips,
  });

  /// Increases with every landing in the controller's lifetime.
  final int serial;

  /// Index of the landed box in [SwipeStackController.stackedBoxes].
  final int floor;
  final bool perfect;
  final BoxSegment landed;

  /// Parts of the dropped box that hung over the edge and were cut off.
  final List<BoxSegment> chips;
}

class SwipeStackController extends ChangeNotifier {
  SwipeStackController({
    required BestStackStore bestStackStore,
    VoidCallback? onDrop,
    VoidCallback? onStackSuccess,
    VoidCallback? onFail,
    math.Random? random,
  }) : _bestStackStore = bestStackStore,
       _onDrop = onDrop,
       _onStackSuccess = onStackSuccess,
       _onFail = onFail,
       _random = random ?? math.Random() {
    _resetRunState(notify: false);
  }

  static const double successThreshold = 0.55;
  static const double verticalTravelUnits = 9.4;
  static const double baseDropSpeedUnitsPerSecond = 15.5;
  static const double baseMoveSpeed = 0.32;
  static const double speedTierDelta = 0.12;
  static const double minVisibleWidth = 0.08;
  static const double maxSwipeDriftUnitsPerSecond = 0.18;
  static const double dragNudgeScale = 1.18;
  static const double maxNudgePerBox = 0.06;
  static const double keyboardNudgeStep = 0.02;
  // Speed stops rising here: at 0.92 playfield widths per second the box still
  // crosses the narrowest lane in a humanly reactable time.
  static const int maxSpeedTier = 5;
  static const double perfectTolerance = 0.015;
  static const double perfectGrowth = 0.03;
  static const int perfectStreakForGrowth = 3;
  static const double baseWidth = 0.74;

  final BestStackStore _bestStackStore;
  final VoidCallback? _onDrop;
  final VoidCallback? _onStackSuccess;
  final VoidCallback? _onFail;
  final math.Random _random;

  final List<BoxSegment> _stackedBoxes = <BoxSegment>[
    const BoxSegment(
      centerX: 0.5,
      widthFactor: baseWidth,
      color: Color(0xFF45647A),
    ),
  ];

  Size _playfieldSize = Size.zero;
  int _bestStack = 0;
  int _stackCount = 0;
  bool _initialized = false;
  bool _isGameOver = false;
  bool _isDropping = false;
  double _movingCenterX = 0.5;
  double _movingDirection = 1;
  double _dropProgressUnits = 0;
  double _dropDriftUnitsPerSecond = 0;
  double _nudgeOffset = 0;
  int _perfectStreak = 0;
  bool _lastDropPerfect = false;
  // Best stack must not be written before the stored value is known.
  bool _bestLoaded = false;
  int _runStartBest = 0;
  int _runPerfectCount = 0;
  int _runBestStreak = 0;
  int _landingSerial = 0;
  LandingInfo? _lastLanding;
  BoxSegment _movingBox = const BoxSegment(
    centerX: 0.5,
    widthFactor: baseWidth,
    color: Color(0xFFFFB14C),
  );

  List<BoxSegment> get stackedBoxes =>
      List<BoxSegment>.unmodifiable(_stackedBoxes);
  BoxSegment get movingBox => _movingBox;
  Size get playfieldSize => _playfieldSize;
  int get bestStack => _bestStack;
  int get stackCount => _stackCount;
  bool get isInitialized => _initialized;
  bool get isGameOver => _isGameOver;
  bool get isDropping => _isDropping;
  int get perfectStreak => _perfectStreak;
  bool get lastDropPerfect => _lastDropPerfect;

  /// Best stack when the current run started (for "New best!").
  int get runStartBest => _runStartBest;
  int get runPerfectCount => _runPerfectCount;
  int get runBestStreak => _runBestStreak;
  LandingInfo? get lastLanding => _lastLanding;
  bool get isPerfectAligned =>
      (_movingBox.centerX - _stackedBoxes.last.centerX).abs() <=
      perfectTolerance;
  int get speedTier => _stackCount ~/ 5;
  int get effectiveSpeedTier => math.min(speedTier, maxSpeedTier);
  bool get isAtMaxSpeed => speedTier >= maxSpeedTier;
  double get moveSpeed => baseMoveSpeed + (effectiveSpeedTier * speedTierDelta);
  double get dropSpeed =>
      baseDropSpeedUnitsPerSecond + (effectiveSpeedTier * 1.05);
  double get dropProgress =>
      (_dropProgressUnits / verticalTravelUnits).clamp(0.0, 1.0);
  double get overlapTargetWidth => _stackedBoxes.last.widthFactor;
  double get projectedOverlapRatio {
    final target = _stackedBoxes.last;
    final overlapLeft = math.max(target.left, _movingBox.left);
    final overlapRight = math.min(target.right, _movingBox.right);
    final overlapWidth = math.max(0.0, overlapRight - overlapLeft);
    return (overlapWidth / _movingBox.widthFactor).clamp(0.0, 1.0);
  }

  String get alignmentLabel {
    final ratio = projectedOverlapRatio;
    if (isPerfectAligned) return 'Perfect';
    if (ratio >= 0.94) return 'Locked';
    if (ratio >= successThreshold) return 'Stackable';
    return 'Risk';
  }

  String get paceLabel {
    if (speedTier < 1) return 'Calm';
    if (speedTier < 2) return 'Quick';
    if (speedTier < 4) return 'Hot';
    return 'Wild';
  }

  Future<void> initialize() async {
    final stored = await _bestStackStore.loadBestStack();
    final reachedMeanwhile = _bestStack;
    _bestStack = math.max(stored, reachedMeanwhile);
    _bestLoaded = true;
    // A run that began before the load started from the stored best.
    _runStartBest = math.max(_runStartBest, stored);
    if (reachedMeanwhile > stored) {
      _bestStackStore.saveBestStack(_bestStack);
    }
    _initialized = true;
    notifyListeners();
  }

  void setPlayfieldSize(Size size) {
    if (_playfieldSize == size || size.isEmpty) {
      return;
    }
    _playfieldSize = size;
  }

  void update(double deltaSeconds) {
    if (deltaSeconds <= 0 || _isGameOver) {
      return;
    }

    if (_isDropping) {
      _dropProgressUnits += dropSpeed * deltaSeconds;
      _applyDropDrift(deltaSeconds);
      if (_dropProgressUnits >= verticalTravelUnits) {
        _resolveDrop();
      } else {
        notifyListeners();
      }
      return;
    }

    if (_playfieldSize.isEmpty) {
      return;
    }

    final halfWidth = _movingBox.widthFactor / 2;
    _movingCenterX += _movingDirection * moveSpeed * deltaSeconds;

    if (_movingCenterX >= 1 - halfWidth) {
      _movingCenterX = 1 - halfWidth;
      _movingDirection = -1;
    } else if (_movingCenterX <= halfWidth) {
      _movingCenterX = halfWidth;
      _movingDirection = 1;
    }

    _movingBox = BoxSegment(
      centerX: _movingCenterX,
      widthFactor: _movingBox.widthFactor,
      color: _movingBox.color,
    );
    notifyListeners();
  }

  void drop() {
    if (_isGameOver || _isDropping) {
      return;
    }

    _beginDrop(0);
  }

  void dropWithSwipeVelocity(double velocityX) {
    if (_isGameOver || _isDropping) {
      return;
    }

    final normalizedVelocity = _playfieldSize.width <= 0
        ? 0.0
        : velocityX / _playfieldSize.width;
    _beginDrop(
      normalizedVelocity.clamp(
        -maxSwipeDriftUnitsPerSecond,
        maxSwipeDriftUnitsPerSecond,
      ),
    );
  }

  void nudgeMovingBox(double deltaX) {
    if (_isGameOver || _isDropping || _playfieldSize.width <= 0) {
      return;
    }

    _applyNudge((deltaX / _playfieldSize.width) * dragNudgeScale);
  }

  /// Keyboard nudge: one fixed step left (-1) or right (+1), sharing the same
  /// per-box cap as drag nudging.
  void nudgeByKey(int direction) {
    if (_isGameOver || _isDropping || direction == 0) {
      return;
    }
    _applyNudge(direction.sign * keyboardNudgeStep);
  }

  void _applyNudge(double units) {
    final requested = _nudgeOffset + units;
    final nextOffset = requested.clamp(-maxNudgePerBox, maxNudgePerBox);
    final step = nextOffset - _nudgeOffset;
    if (step == 0) {
      return;
    }
    final before = _movingCenterX;
    _setMovingCenterX(before + step);
    _nudgeOffset += _movingCenterX - before;
    notifyListeners();
  }

  void _beginDrop(double driftUnitsPerSecond) {
    _isDropping = true;
    _dropProgressUnits = 0;
    _dropDriftUnitsPerSecond = driftUnitsPerSecond;
    _onDrop?.call();
    notifyListeners();
  }

  void restart() {
    _resetRunState(notify: true);
  }

  @visibleForTesting
  void debugSetRun({
    required List<BoxSegment> stack,
    required BoxSegment movingBox,
    int stackCount = 0,
    int bestStack = 0,
    bool isGameOver = false,
    bool isDropping = false,
    double movingDirection = 1,
    int perfectStreak = 0,
  }) {
    _stackedBoxes
      ..clear()
      ..addAll(stack);
    _movingBox = movingBox;
    _movingCenterX = movingBox.centerX;
    _stackCount = stackCount;
    _bestStack = bestStack;
    _isGameOver = isGameOver;
    _isDropping = isDropping;
    _movingDirection = movingDirection;
    _dropProgressUnits = 0;
    _dropDriftUnitsPerSecond = 0;
    _nudgeOffset = 0;
    _perfectStreak = perfectStreak;
    _lastDropPerfect = false;
    _bestLoaded = true;
    _runStartBest = bestStack;
    _runPerfectCount = 0;
    _runBestStreak = perfectStreak;
    _lastLanding = null;
  }

  void _resolveDrop() {
    final target = _stackedBoxes.last;
    final overlapLeft = math.max(target.left, _movingBox.left);
    final overlapRight = math.min(target.right, _movingBox.right);
    final overlapWidth = overlapRight - overlapLeft;
    final overlapRatio = overlapWidth / _movingBox.widthFactor;
    final isPerfect = isPerfectAligned;

    if (overlapWidth <= 0 || overlapRatio < successThreshold) {
      _isDropping = false;
      _isGameOver = true;
      _perfectStreak = 0;
      _lastDropPerfect = false;
      _onFail?.call();
      notifyListeners();
      return;
    }

    final BoxSegment landedBox;
    final dropped = _movingBox;
    if (isPerfect) {
      _perfectStreak += 1;
      _lastDropPerfect = true;
      _runPerfectCount += 1;
      _runBestStreak = math.max(_runBestStreak, _perfectStreak);
      final grownWidth = _perfectStreak >= perfectStreakForGrowth
          ? math.min(baseWidth, target.widthFactor + perfectGrowth)
          : target.widthFactor;
      landedBox = BoxSegment(
        centerX: target.centerX.clamp(grownWidth / 2, 1 - grownWidth / 2),
        widthFactor: grownWidth,
        color: _boxColorFor(_stackCount + 1),
      );
    } else {
      _perfectStreak = 0;
      _lastDropPerfect = false;
      landedBox = BoxSegment(
        centerX: (overlapLeft + overlapRight) / 2,
        widthFactor: math.max(overlapWidth, minVisibleWidth),
        color: _boxColorFor(_stackCount + 1),
      );
    }

    _stackedBoxes.add(landedBox);
    _stackCount += 1;
    if (_stackCount > _bestStack) {
      _bestStack = _stackCount;
      if (_bestLoaded) _bestStackStore.saveBestStack(_bestStack);
    }
    _landingSerial += 1;
    _lastLanding = LandingInfo(
      serial: _landingSerial,
      floor: _stackedBoxes.length - 1,
      perfect: isPerfect,
      landed: landedBox,
      chips: isPerfect
          ? const <BoxSegment>[]
          : <BoxSegment>[
              if (dropped.left < overlapLeft - 1e-6)
                BoxSegment(
                  centerX: (dropped.left + overlapLeft) / 2,
                  widthFactor: overlapLeft - dropped.left,
                  color: dropped.color,
                ),
              if (dropped.right > overlapRight + 1e-6)
                BoxSegment(
                  centerX: (overlapRight + dropped.right) / 2,
                  widthFactor: dropped.right - overlapRight,
                  color: dropped.color,
                ),
            ],
    );

    _movingBox = _nextMovingBox(
      widthFactor: landedBox.widthFactor,
      previousCenterX: landedBox.centerX,
    );
    _movingCenterX = _movingBox.centerX;
    _isDropping = false;
    _dropProgressUnits = 0;
    _dropDriftUnitsPerSecond = 0;
    _onStackSuccess?.call();
    notifyListeners();
  }

  void _applyDropDrift(double deltaSeconds) {
    if (_dropDriftUnitsPerSecond == 0) {
      return;
    }

    final remainingInfluence = 1 - (dropProgress * 0.72);
    _setMovingCenterX(
      _movingCenterX +
          (_dropDriftUnitsPerSecond * remainingInfluence * deltaSeconds),
    );
    _dropDriftUnitsPerSecond *= math.pow(0.42, deltaSeconds).toDouble();
  }

  void _setMovingCenterX(double centerX) {
    final halfWidth = _movingBox.widthFactor / 2;
    _movingCenterX = centerX.clamp(halfWidth, 1 - halfWidth);
    _movingBox = BoxSegment(
      centerX: _movingCenterX,
      widthFactor: _movingBox.widthFactor,
      color: _movingBox.color,
    );
  }

  BoxSegment _nextMovingBox({
    required double widthFactor,
    required double previousCenterX,
  }) {
    final centerX = _rollSpawnCenter(
      widthFactor: widthFactor,
      previousCenterX: previousCenterX,
    );
    _movingDirection = _random.nextBool() ? 1 : -1;
    _nudgeOffset = 0;
    return BoxSegment(
      centerX: centerX,
      widthFactor: widthFactor,
      color: _boxColorFor(_stackCount + 1),
    );
  }

  void _resetRunState({required bool notify}) {
    _stackedBoxes
      ..clear()
      ..add(
        const BoxSegment(
          centerX: 0.5,
          widthFactor: baseWidth,
          color: Color(0xFF45647A),
        ),
      );
    _stackCount = 0;
    _perfectStreak = 0;
    _lastDropPerfect = false;
    _runStartBest = _bestStack;
    _runPerfectCount = 0;
    _runBestStreak = 0;
    _lastLanding = null;
    _isGameOver = false;
    _isDropping = false;
    _dropProgressUnits = 0;
    _dropDriftUnitsPerSecond = 0;
    _movingBox = _nextMovingBox(
      widthFactor: _stackedBoxes.last.widthFactor,
      previousCenterX: 0.5,
    );
    _movingCenterX = _movingBox.centerX;
    if (notify) {
      notifyListeners();
    }
  }

  double _rollSpawnCenter({
    required double widthFactor,
    required double previousCenterX,
  }) {
    final halfWidth = widthFactor / 2;
    final minCenter = halfWidth;
    final maxCenter = 1 - halfWidth;
    final range = maxCenter - minCenter;
    if (range <= 0.001) {
      return previousCenterX.clamp(minCenter, maxCenter);
    }

    var candidate = previousCenterX;
    final minimumShift = math.min(0.22, math.max(0.1, widthFactor * 0.3));
    for (var attempt = 0; attempt < 6; attempt += 1) {
      candidate = minCenter + (_random.nextDouble() * range);
      if ((candidate - previousCenterX).abs() >= minimumShift) {
        return candidate;
      }
    }
    return candidate;
  }

  Color _boxColorFor(int boxIndex) {
    const palette = <Color>[
      Color(0xFFFFB14C),
      Color(0xFFFF8C69),
      Color(0xFFE86A92),
      Color(0xFF7B8CFF),
      Color(0xFF63D6C8),
      Color(0xFFF5DC72),
    ];
    return palette[(boxIndex - 1) % palette.length];
  }
}
