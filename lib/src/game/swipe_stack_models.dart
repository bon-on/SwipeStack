import 'dart:ui';

class BoxSegment {
  const BoxSegment({
    required this.centerX,
    required this.widthFactor,
    required this.color,
  });

  final double centerX;
  final double widthFactor;
  final Color color;

  double get left => centerX - (widthFactor / 2);
  double get right => centerX + (widthFactor / 2);
}
