import 'package:flutter/material.dart';

/// Motion tokens. Every animation pulls its duration from here so the whole
/// product moves at one consistent speed. The values are deliberately a touch
/// longer than a stock Material app: the brief for this build is motion that
/// is *felt* on every interaction, not just decoration.
class Motion {
  const Motion._();

  /// Very quick feedback for direct manipulation (press, toggle).
  static const Duration instant = Duration(milliseconds: 120);

  /// Press-in, ripple settle, chip swap.
  static const Duration fast = Duration(milliseconds: 200);

  /// Default for entrances, tab switches and disclosures.
  static const Duration normal = Duration(milliseconds: 340);

  /// Hero reveals, page bodies, list staggers.
  static const Duration slow = Duration(milliseconds: 520);

  /// Reserved for the single most important moment on a screen.
  static const Duration dramatic = Duration(milliseconds: 760);

  static const Curve entrance = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeOutBack;
  static const Curve spring = Curves.easeOutBack;
  static const Curve swipe = Curves.easeOutQuart;

  /// Stagger between consecutive items in a list entrance.
  static const Duration staggerStep = Duration(milliseconds: 70);

  /// Upper bound on how long the last item of a long list waits, so a 200-row
  /// list does not stay blank for seconds before revealing itself.
  static const Duration staggerCap = Duration(milliseconds: 620);

  /// Scale applied while a card/button is held.
  static const double pressScale = 0.955;

  /// How far an entering block travels before settling.
  static const double enterOffset = 28;
}

/// Fade + slide page transition, applied app-wide through
/// [ThemeData.pageTransitionsTheme].
///
/// The transition is intentionally more expressive than the platform default:
/// content enters from the leading edge over [Motion.slow] while fading, and
/// fades out behind the incoming route so the two never sit on top of each
/// other at full opacity.
class GossPageTransitionBuilder extends PageTransitionsBuilder {
  const GossPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final begin = Offset(isRtl ? -1 : 1, 0);

    final slide = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Motion.swipe));
    // A touch of scale on the way in adds depth without the "zoom" feel of a
    // full 3D transition.
    final scale = Tween<double>(
      begin: 0.96,
      end: 1,
    ).animate(CurvedAnimation(parent: animation, curve: Motion.emphasis));

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Motion.entrance),
      child: ScaleTransition(
        scale: scale,
        child: SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: ReverseAnimation(secondaryAnimation),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The app's primary interaction wrapper.
///
/// Presses produce a scale dip plus a subtle brightness lift, so *every*
/// tappable surface in the app has weight. [onTap] fires on release inside the
/// bounds, [onLongPress] is separate, and [enabled] cleanly disables both
/// without changing layout.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = Motion.pressScale,
    this.lift = true,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  /// Adds a brightness change on press for surfaces with no ink ripple.
  final bool lift;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final interactive =
        widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    final scale = _pressed ? widget.pressedScale : 1.0;
    Widget content = widget.child;

    if (widget.lift) {
      content = AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.entrance,
        foregroundDecoration: BoxDecoration(
          color: _pressed
              ? Colors.black.withValues(alpha: 0.04)
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(6),
        ),
        child: content,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: interactive ? widget.onTap : null,
      onLongPress: interactive ? widget.onLongPress : null,
      onTapDown: interactive ? (_) => _set(true) : null,
      onTapUp: interactive ? (_) => _set(false) : null,
      onTapCancel: interactive ? () => _set(false) : null,
      child: AnimatedScale(
        scale: scale,
        duration: Motion.instant,
        curve: Motion.emphasis,
        child: content,
      ),
    );
  }
}

/// Fades, lifts and slightly scales its child in the first time it is built.
/// This is the workhorse entrance for whole sections: navigating to a screen
/// now visibly assembles rather than snapping into place.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = Motion.enterOffset,
    this.scaleFrom = 0.985,
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final double scaleFrom;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Motion.entrance,
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * t,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Staggers the entrance of its children so a list cascades in.
///
/// Each item starts at `i * Motion.staggerStep`, capped by [Motion.staggerCap]
/// so long lists stay snappy. Disable for very large static lists to avoid
/// building hundreds of animation controllers.
class StaggeredList extends StatelessWidget {
  const StaggeredList({
    super.key,
    required this.children,
    this.enabled = true,
    this.cap = Motion.staggerCap,
  });

  final List<Widget> children;
  final bool enabled;
  final Duration cap;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return Column(children: children);
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          FadeSlideIn(
            delay: Motion.staggerStep * i > cap ? cap : Motion.staggerStep * i,
            child: children[i],
          ),
      ],
    );
  }
}

/// Smoothly reveals or hides a child with height + fade, for expandable rows
/// and disclosure panels.
class AnimatedExpand extends StatelessWidget {
  const AnimatedExpand({
    super.key,
    required this.expanded,
    required this.child,
    this.duration = Motion.normal,
  });

  final bool expanded;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: Motion.entrance,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Motion.entrance,
        switchOutCurve: Motion.exit,
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: expanded
            ? KeyedSubtree(key: const ValueKey('open'), child: child)
            : const SizedBox.shrink(key: ValueKey('closed')),
      ),
    );
  }
}

/// Cross-fades and lifts between keyed children — tab bodies, and the
/// empty/loading/data states inside one surface.
class FadeSwitcher extends StatelessWidget {
  const FadeSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.normal,
      switchInCurve: Motion.entrance,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) {
        // Scale is folded into the transition rather than passed as a named
        // parameter, because AnimatedSwitcher in this SDK exposes only the
        // curve arguments; a small pop on the way in still sells the change.
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.99, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Motion.emphasis),
              ),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Counts a number up to its value so a changed total is noticed rather than
/// silently swapped.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = Motion.slow,
  });

  final num value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Motion.entrance,
      builder: (context, v, _) {
        final rounded = value is int ? v.round() : v;
        return Text('$prefix$rounded$suffix', style: style);
      },
    );
  }
}

/// A tappable card that dips on press. Wraps whole blocks instead of an
/// [InkWell] when the entire surface is the target.
class LiftCard extends StatelessWidget {
  const LiftCard({
    super.key,
    required this.child,
    this.onTap,
    this.lift = 0.035,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double lift;

  @override
  Widget build(BuildContext context) {
    return PressableScale(onTap: onTap, pressedScale: 1 - lift, child: child);
  }
}

/// Pulsing attention dot for a newly arrived item (new request, unread
/// message). Breathes until the caller marks the item as seen, so the eye is
/// pulled to what actually changed.
class PulseBadge extends StatefulWidget {
  const PulseBadge({
    super.key,
    required this.active,
    required this.child,
    this.color = const Color(0xFFD21F26),
  });

  final bool active;
  final Widget child;
  final Color color;

  @override
  State<PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<PulseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseBadge old) {
    super.didUpdateWidget(old);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                blurRadius: 10 * t,
                spreadRadius: 3 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shimmering placeholder used while a list is loading, so an empty state
/// reads as "loading" instead of "broken".
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.radius = 8});

  final Widget child;
  final double radius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1 - 2 * (1 - t), 0),
            end: Alignment(1 - 2 * (1 - t), 0),
            colors: const [
              Color(0x14000000),
              Color(0x2E000000),
              Color(0x14000000),
            ],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(rect),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Global page transitions, installed once in the theme so no screen has to
/// opt in.
PageTransitionsTheme gossPageTransitions() => const PageTransitionsTheme(
  builders: {
    TargetPlatform.android: GossPageTransitionBuilder(),
    TargetPlatform.iOS: GossPageTransitionBuilder(),
    TargetPlatform.macOS: GossPageTransitionBuilder(),
    TargetPlatform.windows: GossPageTransitionBuilder(),
    TargetPlatform.linux: GossPageTransitionBuilder(),
  },
);
