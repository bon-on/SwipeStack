import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_stack/src/art/block_art.dart';
import 'package:swipe_stack/src/art/sky_scenery.dart';
import 'package:swipe_stack/src/art/tower_palette.dart';
import 'package:swipe_stack/src/meta/tower_theme.dart';

class _BlockPainter extends CustomPainter {
  _BlockPainter(this.theme, this.floor, {this.glow = 0, this.dimmed = false});

  final TowerTheme theme;
  final int floor;
  final double glow;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    // Wide, regular and very narrow floors must all paint.
    for (final width in <double>[300, 120, 24, 4, 0]) {
      BlockArt.paint(
        canvas,
        Rect.fromLTWH(0, 0, width, BlockArt.designHeight),
        theme: theme,
        floor: floor,
        glow: glow,
        dimmed: dimmed,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.theme, this.floors);

  final TowerTheme theme;
  final double floors;

  @override
  void paint(Canvas canvas, Size size) {
    SkyScenery.paint(
      canvas,
      size,
      theme: theme,
      floors: floors,
      scrollPx: floors * 32,
      groundY: size.height * 0.9 + floors * 32,
      time: 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Future<void> _paint(WidgetTester tester, CustomPainter painter) async {
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        child: CustomPaint(size: const Size(320, 480), painter: painter),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  for (final theme in TowerTheme.values) {
    for (final floor in <int>[0, 1, 2, 3, 4, 5, 6, 7, 40]) {
      testWidgets('${theme.name} floor $floor paints', (tester) async {
        await _paint(tester, _BlockPainter(theme, floor));
        await _paint(tester, _BlockPainter(theme, floor, glow: 1));
        await _paint(tester, _BlockPainter(theme, floor, dimmed: true));
      });
    }
    for (final floors in <double>[0, 12, 25, 38, 60, 120]) {
      testWidgets('${theme.name} sky at $floors floors paints', (tester) async {
        await _paint(tester, _SkyPainter(theme, floors));
      });
    }
    testWidgets('${theme.name} preview paints locked and unlocked', (
      tester,
    ) async {
      await _paint(tester, ThemePreviewPainter(theme: theme));
      await _paint(tester, ThemePreviewPainter(theme: theme, locked: true));
    });
  }

  test('sky turns from day to space as the tower grows', () {
    final (dayTop, _) = SkyScenery.skyColors(TowerTheme.downtown, 0);
    final (spaceTop, _) = SkyScenery.skyColors(TowerTheme.downtown, 80);
    expect(dayTop.computeLuminance(), greaterThan(0.3));
    expect(spaceTop.computeLuminance(), lessThan(0.02));
    expect(SkyScenery.nightAmount(TowerTheme.downtown, 0), 0);
    expect(SkyScenery.nightAmount(TowerTheme.downtown, 80), 1);
    // Neon starts at dusk.
    expect(SkyScenery.nightAmount(TowerTheme.neon, 0), greaterThan(0.5));
  });

  test('every theme has six floor colors and a lobby', () {
    for (final theme in TowerTheme.values) {
      final palette = TowerPalette.of(theme);
      expect(palette.floors, hasLength(6));
      expect(palette.floorColor(0), palette.lobby);
      expect(palette.floorColor(7), palette.floors[0]);
    }
  });
}
