import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ads/ad_banner.dart';
import '../ads/ad_service.dart';
import '../audio/audio_controller.dart';
import '../persistence/best_stack_store.dart';
import 'swipe_stack_controller.dart';
import 'swipe_stack_painter.dart';

class SwipeStackScreen extends StatefulWidget {
  const SwipeStackScreen({super.key, this.enableAds = false});

  final bool enableAds;

  @override
  State<SwipeStackScreen> createState() => _SwipeStackScreenState();
}

class _SwipeStackScreenState extends State<SwipeStackScreen>
    with SingleTickerProviderStateMixin {
  late final AudioController _audioController;
  late final SwipeStackController _controller;
  late final Ticker _ticker;
  Duration? _previousTick;
  bool _tickerStarted = false;
  bool _wasGameOver = false;
  int _completedRuns = 0;

  @override
  void initState() {
    super.initState();
    _audioController = AudioController();
    _controller = SwipeStackController(
      bestStackStore: BestStackStore(),
      onDrop: () => unawaited(_audioController.playDrop()),
      onStackSuccess: () => unawaited(_audioController.playStackSuccess()),
      onFail: () => unawaited(_audioController.playFail()),
    )..addListener(_handleGameOverAds);
    _ticker = createTicker(_handleTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleGameOverAds);
    _ticker.dispose();
    unawaited(_audioController.dispose());
    _controller.dispose();
    super.dispose();
  }

  void _handleGameOverAds() {
    if (!widget.enableAds) {
      _wasGameOver = _controller.isGameOver;
      return;
    }

    if (_controller.isGameOver && !_wasGameOver) {
      _completedRuns += 1;
      if (_completedRuns % 3 == 0) {
        AdService.instance.showInterstitialIfReady();
      } else {
        unawaited(AdService.instance.loadInterstitial());
      }
    }
    _wasGameOver = _controller.isGameOver;
  }

  void _handleTick(Duration elapsed) {
    final previousTick = _previousTick;
    _previousTick = elapsed;
    if (previousTick == null) {
      return;
    }
    final deltaSeconds =
        (elapsed - previousTick).inMicroseconds /
        Duration.microsecondsPerSecond;
    _controller.update(deltaSeconds);
  }

  Future<void> _bootstrap() async {
    try {
      await _audioController.initialize();
    } catch (_) {}

    try {
      await _controller.initialize();
    } catch (_) {}

    if (!mounted || _tickerStarted) {
      return;
    }

    _tickerStarted = true;
    _ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFF09111B),
              Color(0xFF162332),
              Color(0xFF291C2D),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Header(controller: _controller),
                    const SizedBox(height: 18),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stageSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          _controller.setPlayfieldSize(stageSize);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _controller.isGameOver
                                ? null
                                : _controller.drop,
                            onHorizontalDragUpdate: _controller.isGameOver
                                ? null
                                : (details) {
                                    _controller.nudgeMovingBox(
                                      details.primaryDelta ?? 0,
                                    );
                                  },
                            onHorizontalDragEnd: _controller.isGameOver
                                ? null
                                : (details) {
                                    _controller.dropWithSwipeVelocity(
                                      details.primaryVelocity ?? 0,
                                    );
                                  },
                            child: Stack(
                              children: <Widget>[
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: SwipeStackPainter(
                                      controller: _controller,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 18,
                                  left: 18,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.22,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'Swipe to line up',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 18,
                                  right: 18,
                                  child: _AlignmentBadge(
                                    label: _controller.alignmentLabel,
                                    ratio: _controller.projectedOverlapRatio,
                                  ),
                                ),
                                if (_controller.isGameOver)
                                  Positioned.fill(
                                    child: Center(
                                      child: _GameOverCard(
                                        stackCount: _controller.stackCount,
                                        bestStack: _controller.bestStack,
                                        onRestart: _controller.restart,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _HintBar(controller: _controller),
                    AdBanner(enabled: widget.enableAds),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final SwipeStackController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'SwipeStack',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatChip(
                label: 'Stack',
                value: '${controller.stackCount}',
                accent: const Color(0xFFFFC768),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                label: 'Best',
                value: '${controller.bestStack}',
                accent: const Color(0xFF77E0C1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                label: 'Speed',
                value: 'T${controller.speedTier + 1}',
                accent: const Color(0xFF87A2FF),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HintBar extends StatelessWidget {
  const _HintBar({required this.controller});

  final SwipeStackController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Drag to correct the glide, release to drop. Only the overlap survives.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              controller.paceLabel,
              style: const TextStyle(
                color: Color(0xFFFFD18B),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlignmentBadge extends StatelessWidget {
  const _AlignmentBadge({required this.label, required this.ratio});

  final String label;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final color = ratio >= SwipeStackController.successThreshold
        ? const Color(0xFF77E0C1)
        : const Color(0xFFFF8C69);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label ${(ratio * 100).round()}%',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameOverCard extends StatelessWidget {
  const _GameOverCard({
    required this.stackCount,
    required this.bestStack,
    required this.onRestart,
  });

  final int stackCount;
  final int bestStack;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111C29).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Tower slipped',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Stacked $stackCount boxes. Best run: $bestStack.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRestart, child: const Text('Restart')),
            ],
          ),
        ),
      ),
    );
  }
}
