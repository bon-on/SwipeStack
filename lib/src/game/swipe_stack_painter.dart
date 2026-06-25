import 'dart:ui';

import 'package:flutter/material.dart';

import 'swipe_stack_controller.dart';

class SwipeStackPainter extends CustomPainter {
  const SwipeStackPainter({required this.controller})
    : super(repaint: controller);

  final SwipeStackController controller;

  static const double _boxHeight = 32;
  static const double _movingTopFactor = 0.08;
  static const double _cameraGap = 88;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF101A28),
          Color(0xFF162B3A),
          Color(0xFF2E2333),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28)),
      backgroundPaint,
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i += 1) {
      final y = (size.height / 5) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final stackMetrics = _StackMetrics.forSize(
      size,
      stackCount: controller.stackedBoxes.length,
    );
    final floorTop = stackMetrics.floorTop;
    final floorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.08, floorTop, size.width * 0.84, 14),
      const Radius.circular(12),
    );
    canvas.drawRRect(floorRect, Paint()..color = const Color(0xFF34485C));

    final stacked = controller.stackedBoxes;
    final target = stacked.last;
    _paintLandingGuide(canvas, size, target.left, target.widthFactor, floorTop);

    for (var index = 0; index < stacked.length; index += 1) {
      final box = stacked[index];
      final y = floorTop - ((index + 1) * _boxHeight);
      _paintBox(canvas, size, box.left, box.widthFactor, y, box.color, false);
    }

    final dropProgress = Curves.easeInCubic.transform(controller.dropProgress);
    final movingY =
        lerpDouble(
          size.height * _movingTopFactor,
          stackMetrics.dropTargetTop,
          dropProgress,
        ) ??
        (size.height * _movingTopFactor);
    _paintDropShadow(
      canvas,
      size,
      controller.movingBox.left,
      controller.movingBox.widthFactor,
      movingY,
      dropProgress,
    );
    _paintBox(
      canvas,
      size,
      controller.movingBox.left,
      controller.movingBox.widthFactor,
      movingY,
      controller.movingBox.color,
      controller.isGameOver,
      stretchFactor:
          1 + ((1 - dropProgress) * 0.24 * (controller.isDropping ? 1 : 0)),
    );
  }

  void _paintLandingGuide(
    Canvas canvas,
    Size size,
    double leftFactor,
    double widthFactor,
    double floorTop,
  ) {
    final targetRect = Rect.fromLTWH(
      leftFactor * size.width,
      floorTop - (_boxHeight * 1.9),
      widthFactor * size.width,
      _boxHeight * 0.34,
    );
    final guidePaint = Paint()
      ..color =
          (controller.projectedOverlapRatio >=
                      SwipeStackController.successThreshold
                  ? const Color(0xFF77E0C1)
                  : const Color(0xFFFF8C69))
              .withValues(alpha: 0.26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(7)),
      guidePaint,
    );
  }

  void _paintBox(
    Canvas canvas,
    Size size,
    double leftFactor,
    double widthFactor,
    double top,
    Color color,
    bool dimmed, {
    double stretchFactor = 1,
  }) {
    final adjustedHeight = _boxHeight * stretchFactor;
    final rect = Rect.fromLTWH(
      leftFactor * size.width,
      top - ((adjustedHeight - _boxHeight) / 2),
      widthFactor * size.width,
      adjustedHeight,
    );
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    final fill = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          color.withValues(alpha: dimmed ? 0.55 : 1),
          color.withValues(alpha: dimmed ? 0.28 : 0.72),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRRect(rRect, fill);
    canvas.drawRRect(
      rRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _paintDropShadow(
    Canvas canvas,
    Size size,
    double leftFactor,
    double widthFactor,
    double top,
    double dropProgress,
  ) {
    if (!controller.isDropping) {
      return;
    }
    final rect = Rect.fromLTWH(
      leftFactor * size.width,
      top + 10,
      widthFactor * size.width,
      _boxHeight + 10,
    );
    final shadow = Paint()
      ..color = const Color(
        0xFF000000,
      ).withValues(alpha: (0.18 + (dropProgress * 0.12)).clamp(0.0, 0.4))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      shadow,
    );
  }

  @override
  bool shouldRepaint(covariant SwipeStackPainter oldDelegate) {
    return oldDelegate.controller != controller;
  }
}

class _StackMetrics {
  const _StackMetrics({required this.floorTop, required this.dropTargetTop});

  final double floorTop;
  final double dropTargetTop;

  static _StackMetrics forSize(Size size, {required int stackCount}) {
    final baseFloorTop = size.height * 0.9;
    final naturalTopStackY =
        baseFloorTop - (stackCount * SwipeStackPainter._boxHeight);
    final desiredTopStackY =
        (size.height * SwipeStackPainter._movingTopFactor) +
        SwipeStackPainter._cameraGap;
    final cameraOffset = naturalTopStackY < desiredTopStackY
        ? desiredTopStackY - naturalTopStackY
        : 0.0;
    final floorTop = baseFloorTop + cameraOffset;
    return _StackMetrics(
      floorTop: floorTop,
      dropTargetTop:
          floorTop - ((stackCount + 1) * SwipeStackPainter._boxHeight),
    );
  }
}
