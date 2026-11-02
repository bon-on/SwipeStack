import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../art/block_art.dart';
import '../../meta/tower_theme.dart';
import 'tower_ui.dart';

/// Lets the player pick an unlocked block and skyline theme.
///
/// Owns the keyboard while open: Left/Right move between unlocked themes,
/// Enter and Escape close.
class ThemePickerOverlay extends StatefulWidget {
  const ThemePickerOverlay({
    super.key,
    required this.selected,
    required this.level,
    required this.onSelect,
    required this.onClose,
  });

  final TowerTheme selected;
  final int level;
  final ValueChanged<TowerTheme> onSelect;
  final VoidCallback onClose;

  @override
  State<ThemePickerOverlay> createState() => _ThemePickerOverlayState();
}

class _ThemePickerOverlayState extends State<ThemePickerOverlay> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'ThemePicker');

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

  bool _unlocked(TowerTheme theme) => widget.level >= theme.requiredLevel;

  void _step(int direction) {
    final unlocked = TowerTheme.values.where(_unlocked).toList();
    final index = unlocked.indexOf(widget.selected);
    if (unlocked.isEmpty) return;
    final next = unlocked[(index + direction) % unlocked.length];
    widget.onSelect(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.space) {
        widget.onClose();
      } else if (key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.keyD) {
        _step(1);
      } else if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.keyA) {
        _step(-1);
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Stack(
        children: <Widget>[
          ModalBarrier(
            dismissible: true,
            color: const Color(0x99070A1A),
            onDismiss: widget.onClose,
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: TowerPanel(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  'Tower themes',
                                  style: TextStyle(
                                    color: TowerColors.text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: widget.onClose,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: TowerColors.textSoft,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Level up by building to unlock new blocks and skylines.',
                            style: TextStyle(
                              color: TowerColors.textSoft,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 440
                                  ? 4
                                  : 2;
                              final gap = 10.0;
                              final width =
                                  (constraints.maxWidth - gap * (columns - 1)) /
                                  columns;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: <Widget>[
                                  for (final theme in TowerTheme.values)
                                    SizedBox(
                                      width: width,
                                      child: _ThemeCard(
                                        theme: theme,
                                        selected: theme == widget.selected,
                                        unlocked: _unlocked(theme),
                                        onTap: () => widget.onSelect(theme),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          TowerButton(label: 'Done', onPressed: widget.onClose),
                        ],
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

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  final TowerTheme theme;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: unlocked ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: TowerColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? TowerColors.gold : TowerColors.panelEdge,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 0.9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CustomPaint(
                      painter: ThemePreviewPainter(
                        theme: theme,
                        locked: !unlocked,
                      ),
                    ),
                    if (!unlocked)
                      const Center(
                        child: Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                theme.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TowerColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                selected
                    ? 'Selected'
                    : unlocked
                    ? 'Tap to use'
                    : 'Level ${theme.requiredLevel}',
                maxLines: 1,
                style: TextStyle(
                  color: selected ? TowerColors.gold : TowerColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
