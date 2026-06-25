import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../persistence/best_stack_store.dart';
import 'swipe_stack_models.dart';

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
  static const double maxSwipeDriftUnitsPerSecond = 0.42;
  static const double dragNudgeScale = 1.18;

  final BestStackStore _bestStackStore;
  final VoidCallback? _onDrop;
  final VoidCallback? _onStackSuccess;
  final VoidCallback? _onFail;
  final math.Random _random;

  final List<BoxSegment> _stackedBoxes = <BoxSegment>[
    const BoxSegment(centerX: 0.5, widthFactor: 0.74, color: Color(0xFF45647A)),
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
  BoxSegment _movingBox = const BoxSegment(
    centerX: 0.5,
    widthFactor: 0.74,
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
  int get speedTier => _stackCount ~/ 5;
  double get moveSpeed => baseMoveSpeed + (speedTier * speedTierDelta);
  double get dropSpeed => baseDropSpeedUnitsPerSecond + (speedTier * 1.05);
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
    _bestStack = await _bestStackStore.loadBestStack();
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

    _setMovingCenterX(
      _movingCenterX + ((deltaX / _playfieldSize.width) * dragNudgeScale),
    );
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
  }

  void _resolveDrop() {
    final target = _stackedBoxes.last;
    final overlapLeft = math.max(target.left, _movingBox.left);
    final overlapRight = math.min(target.right, _movingBox.right);
    final overlapWidth = overlapRight - overlapLeft;
    final overlapRatio = overlapWidth / _movingBox.widthFactor;
    final survivedWidth = math.max(overlapWidth, minVisibleWidth);

    if (overlapWidth <= 0 || overlapRatio < successThreshold) {
      _isDropping = false;
      _isGameOver = true;
      _onFail?.call();
      notifyListeners();
      return;
    }

    final landedBox = BoxSegment(
      centerX: (overlapLeft + overlapRight) / 2,
      widthFactor: survivedWidth,
      color: _boxColorFor(_stackCount + 1),
    );

    _stackedBoxes.add(landedBox);
    _stackCount += 1;
    if (_stackCount > _bestStack) {
      _bestStack = _stackCount;
      _bestStackStore.saveBestStack(_bestStack);
    }

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
          widthFactor: 0.74,
          color: Color(0xFF45647A),
        ),
      );
    _stackCount = 0;
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
