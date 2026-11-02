import 'package:flutter/material.dart';

import '../../meta/missions.dart';

/// Shared colors for the SwipeStack interface.
class TowerColors {
  const TowerColors._();

  static const Color backgroundTop = Color(0xFF16204A);
  static const Color backgroundBottom = Color(0xFF2B1C4A);
  static const Color panel = Color(0xFF1E2A5C);
  static const Color panelEdge = Color(0x33FFFFFF);
  static const Color card = Color(0xFF253369);
  static const Color text = Color(0xFFFFFFFF);
  static const Color textSoft = Color(0xB3E6ECFF);
  static const Color textFaint = Color(0x80E6ECFF);
  static const Color gold = Color(0xFFFFC857);
  static const Color mint = Color(0xFF6EE7B7);
  static const Color sky = Color(0xFF8AB4FF);
  static const Color coral = Color(0xFFFF7A7A);
  static const Color buttonTop = Color(0xFFFFD36E);
  static const Color buttonBottom = Color(0xFFFF9F43);
}

/// Rounded glassy panel used by side panels, cards and overlays.
class TowerPanel extends StatelessWidget {
  const TowerPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = TowerColors.panel,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color.lerp(color, Colors.white, 0.06)!, color],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: TowerColors.panelEdge),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small caps label above a value.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    this.icon,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TowerColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: compact ? 6 : 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 12, color: accent),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TowerColors.textSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 2 : 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: accent,
                  fontSize: compact ? 20 : 24,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big warm call-to-action button.
class TowerButton extends StatelessWidget {
  const TowerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.focusNode,
    this.secondary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final FocusNode? focusNode;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final fg = secondary ? TowerColors.text : const Color(0xFF3A2200);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: secondary
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  TowerColors.buttonTop,
                  TowerColors.buttonBottom,
                ],
              ),
        color: secondary ? TowerColors.card : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: secondary ? TowerColors.panelEdge : const Color(0x66FFFFFF),
        ),
        boxShadow: secondary
            ? null
            : const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66FF9F43),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusNode: focusNode,
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button in the panel style.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: TowerColors.card,
        side: const BorderSide(color: TowerColors.panelEdge),
      ),
      icon: Icon(icon, color: TowerColors.textSoft, size: 20),
    );
  }
}

/// "Lv N" badge with an XP bar.
class LevelBar extends StatelessWidget {
  const LevelBar({
    super.key,
    required this.level,
    required this.xpInto,
    required this.xpForNext,
    this.caption,
  });

  final int level;
  final int xpInto;
  final int xpForNext;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final fraction = xpForNext <= 0
        ? 0.0
        : (xpInto / xpForNext).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            LevelBadge(level: level),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Builder level $level',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TowerColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  XpBar(fraction: fraction),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          caption ?? '$xpInto / $xpForNext XP',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: TowerColors.textFaint, fontSize: 11),
        ),
      ],
    );
  }
}

class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.size = 38});

  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[TowerColors.buttonTop, TowerColors.buttonBottom],
        ),
        border: Border.all(color: const Color(0x99FFFFFF), width: 2),
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            '$level',
            style: const TextStyle(
              color: Color(0xFF3A2200),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.fraction, this.height = 8});

  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: Color(0x33FFFFFF)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[TowerColors.mint, Color(0xFF4FC3F7)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title in panels.
class PanelTitle extends StatelessWidget {
  const PanelTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TowerColors.textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// One mission line: check, label and progress.
class MissionRow extends StatelessWidget {
  const MissionRow({super.key, required this.mission, this.dense = false});

  final Mission mission;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final done = mission.completed;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 2 : 4),
      child: Row(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: dense ? 16 : 20,
            height: dense ? 16 : 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? TowerColors.mint : Colors.transparent,
              border: Border.all(
                color: done ? TowerColors.mint : TowerColors.textFaint,
                width: 2,
              ),
            ),
            child: done
                ? Icon(
                    Icons.check_rounded,
                    size: dense ? 11 : 14,
                    color: const Color(0xFF0F3D2E),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mission.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: done ? TowerColors.mint : TowerColors.text,
                fontSize: dense ? 12 : 13,
                fontWeight: FontWeight.w700,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: TowerColors.mint,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            done
                ? '+${mission.xp} XP'
                : '${mission.progress}/${mission.target}',
            style: TextStyle(
              color: done ? TowerColors.gold : TowerColors.textSoft,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
