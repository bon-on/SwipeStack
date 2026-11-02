import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ads/ad_banner.dart';
import '../ads/ad_service.dart';
import '../audio/sound_fx.dart';
import '../audio/sound_mute_store.dart';
import '../meta/missions.dart';
import '../meta/tower_progress.dart';
import '../meta/tower_progress_store.dart';
import '../meta/tower_theme.dart';
import '../persistence/best_stack_store.dart';
import 'how_to_play.dart';
import 'swipe_stack_controller.dart';
import 'swipe_stack_painter.dart';
import 'ui/run_summary_overlay.dart';
import 'ui/theme_picker_overlay.dart';
import 'ui/tower_fx.dart';
import 'ui/tower_ui.dart';

class SwipeStackScreen extends StatefulWidget {
  const SwipeStackScreen({
    super.key,
    this.enableAds = false,
    this.controller,
    this.howToPlayStore = const HowToPlayStore(),
    this.soundMuteStore = const SoundMuteStore(),
    this.progressStore = const TowerProgressStore(),
    this.missions,
  });

  final bool enableAds;

  /// Injected for tests; when null the screen creates and owns its controller.
  final SwipeStackController? controller;

  /// First-run tutorial flag storage; tests inject a fake.
  final HowToPlayStore howToPlayStore;

  /// Persisted user mute choice; tests inject a fake.
  final SoundMuteStore soundMuteStore;

  /// Player XP and theme storage; tests inject a memory store.
  final TowerProgressStore progressStore;

  /// Injected for tests; when null a random board is rolled per run.
  final MissionBoard? missions;

  /// Max width of the play field.
  static const double maxContentWidth = 520;

  /// Landscape viewports at least this wide get side panels.
  static const double wideMinWidth = 600;

  /// Whether a viewport of [size] uses the side-panel layout.
  static bool isWide(Size size) =>
      size.width >= wideMinWidth && size.width > size.height;

  /// Hint shown below (narrow) or beside (wide) the play field.
  static const String hintText =
      'Tap or swipe to drop. Drags only trim the glide. Perfect drops keep your width.';

  @override
  State<SwipeStackScreen> createState() => _SwipeStackScreenState();
}

class _SwipeStackScreenState extends State<SwipeStackScreen>
    with SingleTickerProviderStateMixin {
  late final SoundFx _sound;
  late final SwipeStackController _controller;
  late final MissionBoard _missions;
  late final Ticker _ticker;
  late final AppLifecycleListener _lifecycle;
  final TowerFx _fx = TowerFx();
  final FocusNode _focusNode = FocusNode(debugLabel: 'SwipeStackPlay');
  Duration? _previousTick;
  bool _tickerStarted = false;
  bool _wasGameOver = false;
  int _completedRuns = 0;
  // The simulation and all input are paused while the first-run check is
  // pending (_tutorialLoading) and while the card is open (_showHowTo).
  bool _tutorialLoading = true;
  bool _showHowTo = false;
  bool _showThemes = false;

  TowerProgress _progress = const TowerProgress.initial();
  bool _progressLoaded = false;
  bool _themeTouched = false;
  RunReport? _report;
  int _seenSerial = -1;
  int _seenLength = 1;
  // True once the current run has been applied to the progress.
  bool _runCounted = false;
  bool _newRunHandled = false;
  // The summary entrance plays once per game over, not on every re-show.
  bool _summaryIntroPlayed = false;

  bool get _tutorialBlocking => _tutorialLoading || _showHowTo;
  bool get _overlayBlocking => _tutorialBlocking || _showThemes;

  @override
  void initState() {
    super.initState();
    unawaited(_checkTutorial());
    _sound = SoundFx(store: widget.soundMuteStore);
    unawaited(_loadSoundMuted());
    unawaited(_loadProgress());
    _controller =
        widget.controller ??
        SwipeStackController(
          bestStackStore: BestStackStore(),
          onDrop: () => _sound.play(Sfx.drop),
          onStackSuccess: () => _sound.play(Sfx.stackSuccess),
          onFail: () => _sound.play(Sfx.fail),
        );
    _missions = widget.missions ?? MissionBoard(level: _progress.level);
    _wasGameOver = _controller.isGameOver;
    _seenSerial = _controller.lastLanding?.serial ?? -1;
    _seenLength = _controller.stackedBoxes.length;
    _fx.reset(_seenLength);
    _controller.addListener(_onControllerChanged);
    _ticker = createTicker(_handleTick);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => _sound.setAppVisible(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      ),
    );
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _lifecycle.dispose();
    _controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    _sound.dispose();
    _fx.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ persistence

  Future<void> _checkTutorial() async {
    var seen = false;
    try {
      seen = await widget.howToPlayStore.loadSeen();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _tutorialLoading = false;
      _showHowTo = !seen;
    });
  }

  Future<void> _loadSoundMuted() async {
    try {
      await _sound.initialize();
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
    // Music waits for the stored mute so a muted player never hears a blip
    // (and, on web, for the first user input).
    _sound.startMusic();
  }

  Future<void> _loadProgress() async {
    TowerProgress loaded;
    try {
      loaded = await widget.progressStore.load();
    } catch (_) {
      loaded = const TowerProgress.initial();
    }
    if (!mounted) return;
    // Runs finished before the load are merged in rather than lost.
    final changedMeanwhile = _progress.runs > 0 || _themeTouched;
    setState(() {
      _progressLoaded = true;
      _progress = changedMeanwhile
          ? loaded.mergedWith(
              _progress,
              theme: _themeTouched ? _progress.selectedTheme : null,
            )
          : loaded;
    });
    if (changedMeanwhile) unawaited(_saveProgress());
    // Fresh runs roll missions for the real level.
    if (_controller.stackCount == 0 && widget.missions == null) {
      _missions.reset(level: _progress.level);
    }
  }

  void _setProgress(TowerProgress next) {
    _progress = next;
    // Saving before the stored value has loaded could overwrite it; the
    // merge in _loadProgress saves the combined progress instead.
    if (_progressLoaded) unawaited(_saveProgress());
  }

  Future<void> _saveProgress() async {
    try {
      await widget.progressStore.save(_progress);
    } catch (_) {}
  }

  // ------------------------------------------------------------------ input

  void _toggleSound() {
    unawaited(_sound.setUserMuted(!_sound.userMuted).catchError((Object _) {}));
    setState(() {});
    if (!_overlayBlocking) _refocus();
  }

  void _openHowToPlay() => setState(() => _showHowTo = true);

  void _closeHowToPlay() {
    setState(() => _showHowTo = false);
    _refocus();
    unawaited(_markTutorialSeen());
  }

  Future<void> _markTutorialSeen() async {
    try {
      await widget.howToPlayStore.markSeen();
    } catch (_) {}
  }

  void _openThemes() => setState(() => _showThemes = true);

  void _closeThemes() {
    setState(() => _showThemes = false);
    _refocus();
  }

  void _selectTheme(TowerTheme theme) {
    final next = _progress.withTheme(theme);
    if (next.selectedTheme == _progress.selectedTheme) return;
    _themeTouched = true;
    setState(() => _setProgress(next));
  }

  void _refocus() {
    // The summary card takes focus itself after it builds.
    if (!_controller.isGameOver) _focusNode.requestFocus();
  }

  /// Any key or pointer: browsers only allow music after one.
  void _onAnyInput() => _sound.onUserInput();

  bool _onHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent) _onAnyInput();
    return false;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // Overlays own the keyboard while they are open.
    if (_overlayBlocking) return KeyEventResult.handled;
    // Ignore key repeat so a held key cannot drop several boxes in a row.
    if (event is KeyUpEvent || event is KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Leave browser/OS shortcuts (Cmd/Ctrl+R etc.) alone.
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final isDropKey =
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.arrowDown;
    if (_controller.isGameOver) {
      // Drop keys go through the summary card (which arms them after its
      // entrance); R and Escape restart at once.
      if (key == LogicalKeyboardKey.keyR || key == LogicalKeyboardKey.escape) {
        _restart();
        return KeyEventResult.handled;
      }
      return isDropKey ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (isDropKey) {
      _controller.drop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _controller.nudgeByKey(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _controller.nudgeByKey(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      _restart();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Restarts the run. A run abandoned mid-way still counts for XP.
  void _restart() {
    if (!_controller.isGameOver) _finishRun();
    _newRunHandled = false;
    _controller.restart();
    // A restart that did not shrink the stack (0 floors) is still a new run;
    // otherwise the controller listener has already reset it.
    if (!_newRunHandled) _onNewRun();
    _refocus();
  }

  // -------------------------------------------------------------- run state

  void _onControllerChanged() {
    final c = _controller;
    final length = c.stackedBoxes.length;
    // Restarts not made through _restart (e.g. an injected controller).
    if (!c.isGameOver &&
        (length < _seenLength || (_wasGameOver && c.stackCount == 0))) {
      _onNewRun();
    }
    _seenLength = length;

    final landing = c.lastLanding;
    if (landing != null && landing.serial != _seenSerial) {
      _seenSerial = landing.serial;
      _onLanding(landing);
    }

    if (c.isGameOver && !_wasGameOver) {
      _wasGameOver = true;
      _onGameOver();
    } else if (!c.isGameOver && _wasGameOver) {
      _wasGameOver = false;
      if (_report != null) setState(() => _report = null);
    }
  }

  void _onNewRun() {
    _newRunHandled = true;
    _summaryIntroPlayed = false;
    _fx.reset(_controller.stackedBoxes.length);
    _missions.reset(level: _progress.level);
    _runCounted = false;
    setState(() => _report = null);
  }

  void _onLanding(LandingInfo landing) {
    final streak = _controller.perfectStreak;
    _fx.onLanding(landing, streak: streak);
    if (landing.perfect) {
      _sound.play(
        streak >= SwipeStackController.perfectStreakForGrowth
            ? Sfx.streak
            : Sfx.perfect,
      );
    }
    final done = _missions.update(_missionStats());
    if (done.isNotEmpty) {
      final mission = done.first;
      _fx.showBanner(
        'Mission complete',
        '${mission.label}  +${mission.xp} XP',
        TowerColors.mint,
      );
      _sound.play(Sfx.mission);
    }
    // Missions and HUD values are widgets; rebuild them.
    setState(() {});
  }

  MissionStats _missionStats() => MissionStats(
    floors: _controller.stackCount,
    perfects: _controller.runPerfectCount,
    bestStreak: _controller.runBestStreak,
    topWidth: _controller.stackedBoxes.last.widthFactor,
  );

  void _onGameOver() {
    _fx.onCollapse(_controller.stackedBoxes, _controller.movingBox);
    final outcome = _finishRun();
    if (outcome != null && outcome.leveledUp && _progressLoaded) {
      _sound.play(Sfx.levelUp);
    }
    _handleGameOverAds();
  }

  /// Applies the current run to the saved progress once.
  RunOutcome? _finishRun() {
    if (_runCounted) return null;
    _runCounted = true;
    final c = _controller;
    final before = _progress;
    final outcome = before.applyRun(
      RunSummary(
        floors: c.stackCount,
        perfects: c.runPerfectCount,
        bestStreak: c.runBestStreak,
        missionXp: _missions.earnedXp,
      ),
    );
    if (!identical(outcome.progress, before)) _setProgress(outcome.progress);
    if (c.isGameOver) {
      setState(() {
        _report = RunReport(
          floors: c.stackCount,
          best: c.bestStack,
          isNewBest: c.stackCount > 0 && c.stackCount > c.runStartBest,
          perfects: c.runPerfectCount,
          bestStreak: c.runBestStreak,
          missions: _missions.missions,
          xpGained: outcome.xpGained,
          levelBefore: outcome.levelBefore,
          totalXpAfter: outcome.progress.totalXp,
          unlockedThemes: outcome.newlyUnlockedThemes,
          progressKnown: _progressLoaded,
        );
      });
    }
    return outcome;
  }

  void _handleGameOverAds() {
    if (!widget.enableAds) return;
    _completedRuns += 1;
    if (_completedRuns % 3 == 0) {
      // The music must not play over a full-screen ad.
      _sound.stopMusic();
      final shown = AdService.instance.showInterstitialIfReady(
        onClosed: _resumeMusicAfterAd,
      );
      if (!shown) _resumeMusicAfterAd();
    } else {
      unawaited(AdService.instance.loadInterstitial());
    }
  }

  void _resumeMusicAfterAd() {
    if (!mounted) return;
    _sound.startMusic();
  }

  void _handleTick(Duration elapsed) {
    final previousTick = _previousTick;
    _previousTick = elapsed;
    if (previousTick == null) return;
    final deltaSeconds =
        (elapsed - previousTick).inMicroseconds /
        Duration.microsecondsPerSecond;
    // Effects keep running behind overlays; the game itself pauses. The
    // tick time is still recorded so closing a card causes no time jump.
    _fx.tick(deltaSeconds, _controller.stackedBoxes.length);
    if (_overlayBlocking) return;
    _controller.update(deltaSeconds);
  }

  Future<void> _bootstrap() async {
    try {
      await _controller.initialize();
    } catch (_) {}

    if (!mounted || _tickerStarted) {
      return;
    }

    _tickerStarted = true;
    _ticker.start();
  }

  // ------------------------------------------------------------------ build

  /// True the first time the summary is built for this game over.
  bool _takeSummaryIntro() {
    final play = !_summaryIntroPlayed;
    _summaryIntroPlayed = true;
    return play;
  }

  RunReport _fallbackReport() {
    // Shown when the screen opens on an already finished run.
    final c = _controller;
    return RunReport(
      floors: c.stackCount,
      best: c.bestStack,
      isNewBest: false,
      perfects: c.runPerfectCount,
      bestStreak: c.runBestStreak,
      missions: _missions.missions,
      xpGained: 0,
      levelBefore: _progress.level,
      totalXpAfter: _progress.totalXp,
      unlockedThemes: const <TowerTheme>[],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _onAnyInput(),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                TowerColors.backgroundTop,
                TowerColors.backgroundBottom,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKeyEvent,
            child: Stack(
              children: <Widget>[
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = SwipeStackScreen.isWide(constraints.biggest);
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => wide
                            ? _buildWide(constraints.biggest)
                            : _buildNarrow(),
                      );
                    },
                  ),
                ),
                if (_controller.isGameOver && !_overlayBlocking)
                  Positioned.fill(
                    child: RunSummaryOverlay(
                      animateIn: _takeSummaryIntro(),
                      report: _report ?? _fallbackReport(),
                      onPlayAgain: _restart,
                      onThemes: _openThemes,
                    ),
                  ),
                if (_showThemes)
                  Positioned.fill(
                    child: ThemePickerOverlay(
                      selected: _progress.selectedTheme,
                      level: _progress.level,
                      onSelect: _selectTheme,
                      onClose: _closeThemes,
                    ),
                  ),
                if (_showHowTo)
                  Positioned.fill(
                    child: HowToPlayOverlay(
                      steps: _howToPlaySteps,
                      onClose: _closeHowToPlay,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    final c = _controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        c.setPlayfieldSize(Size(constraints.maxWidth, constraints.maxHeight));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: c.isGameOver ? null : c.drop,
          onHorizontalDragUpdate: c.isGameOver
              ? null
              : (details) => c.nudgeMovingBox(details.primaryDelta ?? 0),
          onHorizontalDragEnd: c.isGameOver
              ? null
              : (details) =>
                    c.dropWithSwipeVelocity(details.primaryVelocity ?? 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x40FFFFFF), width: 2),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: SwipeStackPainter(
                        controller: c,
                        fx: _fx,
                        theme: _progress.selectedTheme,
                      ),
                    ),
                  ),
                ),
                if (c.stackCount == 0 && !c.isDropping && !c.isGameOver)
                  const Positioned(
                    top: 14,
                    left: 14,
                    child: _StageChip(
                      text: 'Swipe to line up',
                      color: Color(0xCCFFFFFF),
                    ),
                  ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: _AlignmentBadge(
                    label: c.alignmentLabel,
                    ratio: c.projectedOverlapRatio,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  // Below the drop zone, over the tower body.
                  bottom: constraints.maxHeight * 0.22,
                  child: IgnorePointer(child: _FxBanner(fx: _fx)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statRow({required bool compact}) {
    final c = _controller;
    return Row(
      children: <Widget>[
        Expanded(
          child: StatTile(
            label: 'Stack',
            value: '${c.stackCount}',
            accent: TowerColors.gold,
            icon: Icons.apartment_rounded,
            compact: compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatTile(
            label: 'Best',
            value: '${c.bestStack}',
            accent: TowerColors.mint,
            icon: Icons.emoji_events_rounded,
            compact: compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatTile(
            label: 'Speed',
            value: c.isAtMaxSpeed ? 'MAX' : 'T${c.speedTier + 1}',
            accent: TowerColors.sky,
            icon: Icons.speed_rounded,
            compact: compact,
          ),
        ),
      ],
    );
  }

  Widget _title({double size = 26}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _LogoMark(size: size + 6),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'SwipeStack',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              color: TowerColors.text,
              letterSpacing: -0.5,
              shadows: const <Shadow>[
                Shadow(color: Color(0x66000000), offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RoundIconButton(
          icon: Icons.help_outline_rounded,
          tooltip: 'How to play',
          onPressed: _openHowToPlay,
        ),
        const SizedBox(width: 6),
        RoundIconButton(
          icon: _sound.userMuted
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          tooltip: _sound.userMuted ? 'Sound off' : 'Sound on',
          onPressed: _toggleSound,
        ),
      ],
    );
  }

  String get _paceText => _controller.lastDropPerfect
      ? 'Perfect x${_controller.perfectStreak}'
      : _controller.paceLabel;

  Widget _buildWide(Size size) {
    final p = _progress;
    final roomy = size.height >= 560;
    final gap = roomy ? 20.0 : 12.0;
    final side = ((size.width - SwipeStackScreen.maxContentWidth - gap * 4) / 2)
        .clamp(190.0, 280.0);
    return Padding(
      padding: EdgeInsets.all(gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: side,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _title(size: roomy ? 28 : 22),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: _iconButtons()),
                  SizedBox(height: roomy ? 14 : 10),
                  _statRow(compact: !roomy),
                  const SizedBox(height: 12),
                  TowerPanel(
                    child: LevelBar(
                      level: p.level,
                      xpInto: p.xpIntoLevel,
                      xpForNext: p.xpForNextLevel,
                      caption: _nextUnlockCaption(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ThemeButton(theme: p.selectedTheme, onPressed: _openThemes),
                  const SizedBox(height: 12),
                  TowerPanel(child: _Records(progress: p)),
                ],
              ),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: SwipeStackScreen.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: _buildStage()),
                    AdBanner(enabled: widget.enableAds),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: gap),
          SizedBox(
            width: side,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TowerPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        PanelTitle(
                          'Missions',
                          trailing: Text(
                            '${_missions.completedCount}/3',
                            style: const TextStyle(
                              color: TowerColors.gold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final m in _missions.missions)
                          MissionRow(mission: m),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TowerPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        PanelTitle(
                          'Rhythm',
                          trailing: Text(
                            _paceText,
                            style: const TextStyle(
                              color: Color(0xFFFFD18B),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          SwipeStackScreen.hintText,
                          style: TextStyle(
                            color: TowerColors.textSoft,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const TowerPanel(child: _KeyHelp()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _nextUnlockCaption() {
    final p = _progress;
    for (final theme in TowerTheme.values) {
      if (p.level < theme.requiredLevel) {
        return '${p.xpIntoLevel} / ${p.xpForNextLevel} XP  -  ${theme.label} at Lv ${theme.requiredLevel}';
      }
    }
    return '${p.xpIntoLevel} / ${p.xpForNextLevel} XP  -  all themes open';
  }

  Widget _buildNarrow() {
    final p = _progress;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _title(size: 24),
                    ),
                  ),
                  _LevelChip(
                    level: p.level,
                    fraction: p.xpForNextLevel <= 0
                        ? 0
                        : p.xpIntoLevel / p.xpForNextLevel,
                    onPressed: _openThemes,
                  ),
                  const SizedBox(width: 6),
                  _iconButtons(),
                ],
              ),
              const SizedBox(height: 10),
              _statRow(compact: true),
              const SizedBox(height: 10),
              Expanded(child: _buildStage()),
              const SizedBox(height: 10),
              TowerPanel(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final m in _missions.missions)
                      MissionRow(mission: m, dense: true),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _HintBar(pace: _paceText),
              AdBanner(enabled: widget.enableAds),
            ],
          ),
        ),
      ),
    );
  }
}

const List<HowToPlayStep> _howToPlaySteps = <HowToPlayStep>[
  HowToPlayStep(
    icon: Icons.layers,
    text:
        'Stack boxes as high as you can. A box slides side to side: drop it '
        'onto the tower.',
  ),
  HowToPlayStep(
    icon: Icons.touch_app,
    text:
        'Tap or swipe to drop; dragging nudges slightly. Keyboard: Space/Enter '
        'drop, A/D or arrows nudge.',
  ),
  HowToPlayStep(
    icon: Icons.straighten,
    text:
        'Overlap at least 55% or the tower slips. Perfect drops keep your '
        'width; 3 in a row regrow it.',
  ),
];

class _HintBar extends StatelessWidget {
  const _HintBar({required this.pace});

  final String pace;

  @override
  Widget build(BuildContext context) {
    return TowerPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      radius: 16,
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              SwipeStackScreen.hintText,
              style: TextStyle(
                color: TowerColors.textSoft,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            pace,
            style: const TextStyle(
              color: Color(0xFFFFD18B),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lifetime totals kept across runs.
class _Records extends StatelessWidget {
  const _Records({required this.progress});

  final TowerProgress progress;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: TowerColors.textSoft, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: TowerColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const PanelTitle('Records'),
        const SizedBox(height: 6),
        line('Floors built', '${progress.totalFloors}'),
        line('Towers raised', '${progress.runs}'),
        line('Longest perfect streak', 'x${progress.bestStreak}'),
      ],
    );
  }
}

class _KeyHelp extends StatelessWidget {
  const _KeyHelp();

  @override
  Widget build(BuildContext context) {
    Widget row(String keys, String action) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Flexible(
            flex: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                child: Text(
                  keys,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TowerColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              action,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: TowerColors.textSoft, fontSize: 12),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const PanelTitle('Controls'),
        const SizedBox(height: 6),
        row('Space / Enter', 'Drop the floor'),
        row('A / D  or  arrows', 'Nudge left or right'),
        row('R', 'Restart'),
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x59101830),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          text,
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

class _AlignmentBadge extends StatelessWidget {
  const _AlignmentBadge({required this.label, required this.ratio});

  final String label;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final color = ratio >= SwipeStackController.successThreshold
        ? TowerColors.mint
        : TowerColors.coral;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x80101830),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          '$label ${(ratio * 100).round()}%',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Level ring that opens the theme picker (narrow layout).
class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.level,
    required this.fraction,
    required this.onPressed,
  });

  final int level;
  final double fraction;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Themes',
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  strokeWidth: 3,
                  backgroundColor: const Color(0x33FFFFFF),
                  color: TowerColors.mint,
                ),
              ),
              LevelBadge(level: level, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.theme, required this.onPressed});

  final TowerTheme theme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TowerButton(
      label: 'Theme: ${theme.label}',
      icon: Icons.palette_outlined,
      secondary: true,
      onPressed: onPressed,
    );
  }
}

/// Little stacked-floors logo.
class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const colors = <Color>[
      Color(0xFF5FA8D3),
      Color(0xFFE76F51),
      Color(0xFFF2A65A),
    ];
    final h = size.height / 3.4;
    final widths = <double>[1, 0.8, 0.62];
    final offsets = <double>[0, 0.06, -0.02];
    for (var i = 0; i < 3; i++) {
      final w = size.width * widths[i];
      final rect = Rect.fromLTWH(
        (size.width - w) / 2 + offsets[i] * size.width,
        size.height - (i + 1) * (h + 1),
        w,
        h,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(h * 0.3)),
        Paint()..color = colors[i],
      );
      final win = Paint()..color = const Color(0xCCFFFFFF);
      for (var x = rect.left + 3; x < rect.right - 4; x += 5) {
        canvas.drawRect(Rect.fromLTWH(x, rect.top + h * 0.3, 2, h * 0.4), win);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Banner for streaks and missions; pops in and fades out on the fx clock.
class _FxBanner extends StatelessWidget {
  const _FxBanner({required this.fx});

  final TowerFx fx;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: fx,
      builder: (context, _) {
        final banner = fx.banner;
        if (banner == null) return const SizedBox.shrink();
        final t = fx.clock - banner.start;
        final appear = Curves.easeOutBack.transform((t / 0.25).clamp(0.0, 1.0));
        final fade =
            1 - ((t - (BannerFx.duration - 0.35)) / 0.35).clamp(0.0, 1.0);
        return Opacity(
          opacity: (fade * math.min(1, t / 0.08)).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.6 + 0.4 * appear,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xD9141B3D),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: banner.color, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: banner.color.withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        banner.title,
                        style: TextStyle(
                          color: banner.color,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        banner.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: TowerColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
