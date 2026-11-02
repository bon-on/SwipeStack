import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../meta/missions.dart';
import '../../meta/tower_progress.dart';
import '../../meta/tower_theme.dart';
import 'tower_ui.dart';

/// Everything the run summary shows.
class RunReport {
  const RunReport({
    required this.floors,
    required this.best,
    required this.isNewBest,
    required this.perfects,
    required this.bestStreak,
    required this.missions,
    required this.xpGained,
    required this.levelBefore,
    required this.totalXpAfter,
    required this.unlockedThemes,
  });

  final int floors;
  final int best;
  final bool isNewBest;
  final int perfects;
  final int bestStreak;
  final List<Mission> missions;
  final int xpGained;
  final int levelBefore;
  final int totalXpAfter;
  final List<TowerTheme> unlockedThemes;

  int get levelAfter => TowerProgress.levelFor(totalXpAfter).$1;
}

/// Game-over card: result, best, missions, XP and level progress.
///
/// Owns the keyboard while open: Enter, Space, R and Escape play again.
class RunSummaryOverlay extends StatefulWidget {
  const RunSummaryOverlay({
    super.key,
    required this.report,
    required this.onPlayAgain,
    required this.onThemes,
  });

  final RunReport report;
  final VoidCallback onPlayAgain;
  final VoidCallback onThemes;

  @override
  State<RunSummaryOverlay> createState() => _RunSummaryOverlayState();
}

class _RunSummaryOverlayState extends State<RunSummaryOverlay> {
  static const Duration entrance = Duration(milliseconds: 1300);

  final FocusNode _focusNode = FocusNode(debugLabel: 'RunSummary');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.keyR ||
            key == LogicalKeyboardKey.escape)) {
      widget.onPlayAgain();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final (levelAfter, xpInto) = TowerProgress.levelFor(r.totalXpAfter);
    final xpNext = TowerProgress.xpToAdvance(levelAfter);
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Stack(
        children: <Widget>[
          // The scrim and card wait for the collapse to play out; the
          // keyboard and buttons work from the first frame.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: entrance,
            curve: const Interval(0.45, 0.75),
            builder: (context, t, _) => ModalBarrier(
              dismissible: false,
              color: Color.fromRGBO(7, 10, 26, 0.55 * t),
            ),
          ),
          SafeArea(
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: entrance,
                curve: const Interval(0.55, 1, curve: Curves.easeOutBack),
                builder: (context, t, child) => Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 40 * (1 - t)),
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: TowerPanel(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'Tower slipped',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: TowerColors.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Stacked ${r.floors} ${r.floors == 1 ? 'floor' : 'floors'}. Best run: ${r.best}.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: TowerColors.textSoft,
                                fontSize: 13,
                              ),
                            ),
                            if (r.isNewBest) ...<Widget>[
                              const SizedBox(height: 10),
                              const Center(child: _NewBestBadge()),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: StatTile(
                                    label: 'HEIGHT',
                                    value: '${r.floors}F',
                                    accent: TowerColors.gold,
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: StatTile(
                                    label: 'PERFECT',
                                    value: '${r.perfects}',
                                    accent: TowerColors.mint,
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: StatTile(
                                    label: 'STREAK',
                                    value: 'x${r.bestStreak}',
                                    accent: TowerColors.sky,
                                    compact: true,
                                  ),
                                ),
                              ],
                            ),
                            if (r.missions.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 14),
                              const PanelTitle('Missions'),
                              const SizedBox(height: 4),
                              for (final m in r.missions)
                                MissionRow(mission: m, dense: true),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: <Widget>[
                                const Expanded(child: PanelTitle('Builder XP')),
                                Text(
                                  '+${r.xpGained} XP',
                                  style: const TextStyle(
                                    color: TowerColors.gold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                LevelBadge(level: levelAfter, size: 34),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: xpNext <= 0 ? 0 : xpInto / xpNext,
                                    ),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, f, _) =>
                                        XpBar(fraction: f, height: 10),
                                  ),
                                ),
                              ],
                            ),
                            if (levelAfter > r.levelBefore) ...<Widget>[
                              const SizedBox(height: 8),
                              Text(
                                'Level up! Builder level $levelAfter',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: TowerColors.mint,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                            for (final theme in r.unlockedThemes) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                'New theme unlocked: ${theme.label}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: TowerColors.gold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TowerButton(
                              label: 'Play again',
                              icon: Icons.replay_rounded,
                              onPressed: widget.onPlayAgain,
                            ),
                            const SizedBox(height: 8),
                            TowerButton(
                              label: 'Themes',
                              icon: Icons.palette_outlined,
                              secondary: true,
                              onPressed: widget.onThemes,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewBestBadge extends StatelessWidget {
  const _NewBestBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: <Color>[TowerColors.buttonTop, TowerColors.buttonBottom],
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.emoji_events_rounded,
              size: 16,
              color: Color(0xFF3A2200),
            ),
            SizedBox(width: 6),
            Text(
              'New best!',
              style: TextStyle(
                color: Color(0xFF3A2200),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
