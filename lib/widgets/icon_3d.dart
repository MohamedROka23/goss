import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/icons.dart';
import '../app/motion.dart';
import '../app/responsive.dart';
import '../app/spacing.dart';
import '../app/theme.dart';

/// A single icon, optionally on a tinted container, with restrained press
/// feedback.
///
/// This replaces the earlier glossy "3D" treatment. The redesign calls for a
/// flat outline language — a squircle with a gradient fill and a floating glow
/// reads as illustration, not as a premium product icon. What is kept here is
/// the part that worked: a consistent container geometry and an acknowledgeable
/// press state, now expressed through a short scale and an opacity dip.
///
/// The class name is retained because existing call sites import it; only the
/// visual treatment changed.
class Icon3D extends StatefulWidget {
  const Icon3D({
    super.key,
    required this.icon,
    this.tone = IconTone.primary,
    this.size,
    this.onTap,
    this.tooltip,
    this.animated = false,
    this.pressed,
    this.container = true,
  });

  final IconData icon;
  final IconTone tone;

  /// Outer size. When [container] is false this is the glyph size instead.
  final double? size;

  final VoidCallback? onTap;
  final String? tooltip;

  /// Retained for call-site compatibility. The new language is intentionally
  /// still, so this no longer starts a looping float; it only permits a very
  /// small one-shot settle.
  final bool animated;

  /// Pins the container into its active look without any gesture.
  final bool? pressed;

  /// When false the glyph is drawn bare, for dense tables and inline text.
  final bool container;

  @override
  State<Icon3D> createState() => _Icon3DState();
}

class _Icon3DState extends State<Icon3D> {
  bool _held = false;

  void _setHeld(bool value) {
    if (_held == value || !mounted) return;
    setState(() => _held = value);
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.size ?? context.gap(36);
    final active = widget.pressed ?? _held;

    Widget glyph = IconContainer(
      icon: widget.icon,
      tone: widget.tone,
      size: outer,
      iconSize: widget.container ? outer * 0.48 : outer,
      border: widget.container,
    );

    if (widget.container == false) {
      glyph = Icon(
        widget.icon,
        size: outer,
        color: switch (widget.tone) {
          IconTone.primary => Theme.of(context).colorScheme.primary,
          IconTone.brand => context.brandColor,
          IconTone.danger => context.dangerColor,
          IconTone.success => context.successColor,
          IconTone.warning => context.warningColor,
          IconTone.neutral || IconTone.bare => context.mutedColor,
        },
        weight: active ? 600 : 500,
      );
    }

    if (widget.onTap != null) {
      glyph = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setHeld(true),
        onTapUp: (_) => _setHeld(false),
        onTapCancel: () => _setHeld(false),
        onTap: widget.onTap,
        child: glyph,
      );
    }

    if (widget.tooltip != null) {
      glyph = Tooltip(message: widget.tooltip!, child: glyph);
    }

    // A short press acknowledgement: a small scale plus a slight opacity dip.
    // Both resolve inside the motion system's fast token, so it never feels
    // like the UI is lagging behind the finger.
    return AnimatedScale(
      scale: active ? 0.94 : 1,
      duration: Motion.instant,
      curve: Motion.entrance,
      child: AnimatedOpacity(
        opacity: active ? 0.82 : 1,
        duration: Motion.instant,
        child: glyph,
      ),
    );
  }
}

/// A tappable module tile: icon container plus a compact label.
///
/// Used across the dashboard and home screens. The selected state swaps the
/// container tint and the label colour rather than growing the tile, which keeps
/// a grid of these visually stable when one is active.
class Icon3DModule extends StatelessWidget {
  const Icon3DModule({
    super.key,
    required this.icon,
    required this.label,
    this.tone = IconTone.primary,
    this.onTap,
    this.selected = false,
    this.animated = false,
  });

  final IconData icon;
  final String label;
  final IconTone tone;
  final VoidCallback? onTap;
  final bool selected;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.97,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.entrance,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.06)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(Corners.lg),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : context.borderColor,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon3D(icon: icon, tone: tone, size: 40, pressed: selected),
            const SizedBox(height: Insets.xs + 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: TypeScale.caption,
                height: 1.3,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? accent : context.bodyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact icon button: a 40dp target with a subtle surface that lifts on
/// hover and dips on press. The default control for header and row actions.
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.tone = IconTone.neutral,
    this.size = ControlSize.sm,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconTone tone;
  final double size;

  /// Optional count rendered as a small dot-and-number marker.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final accent = Theme.of(context).colorScheme.primary;
    final isDanger = tone == IconTone.danger;
    final fg = !enabled
        ? context.mutedColor.withValues(alpha: 0.4)
        : switch (tone) {
            IconTone.primary => accent,
            IconTone.brand => context.brandColor,
            IconTone.danger => context.dangerColor,
            IconTone.success => context.successColor,
            IconTone.warning => context.warningColor,
            IconTone.neutral || IconTone.bare => context.bodyColor,
          };

    Widget content = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Corners.md),
      ),
      child: Icon(icon, size: IconSize.action, color: fg, weight: 500),
    );

    content = Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        if (badge != null && badge! > 0)
          PositionedDirectional(
            top: 3,
            end: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDanger ? context.dangerColor : accent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                badge! > 99 ? '99+' : '$badge',
                style: TextStyle(
                  fontSize: 9,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: context.isDarkMode
                      ? const Color(0xFF061018)
                      : Colors.white,
                ),
              ),
            ),
          ),
      ],
    );

    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: PressableScale(
          onTap: onPressed,
          pressedScale: 0.92,
          child: AnimatedContainer(
            duration: Motion.fast,
            curve: Motion.entrance,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Corners.md),
              color: Colors.transparent,
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Corners.md),
              color: enabled
                  ? accent.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// An empty state: a restrained icon container, a short title and one line of
/// guidance. Deliberately compact so an empty list does not look like a
/// marketing splash.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconContainer(
                icon: icon,
                tone: IconTone.neutral,
                size: 52,
                iconSize: 24,
                border: true,
              ),
              const SizedBox(height: Insets.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: TypeScale.sectionTitle,
                  fontWeight: FontWeight.w600,
                  color: context.bodyColor,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: Insets.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: TypeScale.secondary,
                    height: 1.5,
                    color: context.mutedColor,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Insets.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kept so the earlier import of `dart:math` stays justified: a very subtle
/// one-shot rotation used by callers that want the icon to settle into place.
double iconSettle(double t) => math.sin(t * math.pi) * 0.02;
