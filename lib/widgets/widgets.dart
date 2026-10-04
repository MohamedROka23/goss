import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../app/icons.dart';
import '../app/responsive.dart';
import '../app/motion.dart';
import '../app/spacing.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/export_service.dart';

/// Colour used to paint a request status.
///
/// The meanings are unchanged from the original app; only the values moved to
/// the new system, so a chip reads as part of one palette. Note `delivering`
/// uses burgundy rather than plain red: it is an active brand state, not an
/// error, and the two should not look identical at a glance.
Color requestStatusColor(String status) {
  switch (status) {
    case RequestStatus.accepted:
    case RequestStatus.confirmed:
      return GossColors.statusPending;
    case RequestStatus.preparing:
      return GossColors.statusPreparing;
    case RequestStatus.arriving:
      return GossColors.statusArriving;
    case RequestStatus.delivering:
      return GossColors.statusDelivering;
    case RequestStatus.delivered:
      return GossColors.statusDelivered;
    case RequestStatus.rejected:
      return GossColors.statusRejected;
    default:
      return GossColors.statusRejected;
  }
}

/// Small status chip.
///
/// A low-alpha tint with a hairline edge and readable text, rather than a
/// saturated solid pill. The label truncates rather than overflows, which
/// matters for the long Arabic labels inside a narrow order row.
class RequestStatusChip extends StatelessWidget {
  final String status;
  final bool isArabic;
  const RequestStatusChip({
    super.key,
    required this.status,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final color = requestStatusColor(status);
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xs + 2,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(Corners.sm),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.28 : 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Insets.xs - 2),
          Flexible(
            child: Text(
              requestStatusLabel(status, ar: isArabic),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: isDark ? color.withValues(alpha: 0.95) : color,
                fontSize: TypeScale.micro,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal stage-by-stage timeline for an order's journey.
///
/// Completed stages sit on the accent colour with a connecting rail; pending
/// stages are outlined only, which reads as a progression without needing
/// per-stage labels.
class RequestStatusTimeline extends StatelessWidget {
  final int step;
  const RequestStatusTimeline({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    final stages = RequestStatus.stages;
    final accent = Theme.of(context).colorScheme.primary;
    final idle = context.borderColor;
    final activeColor = Theme.of(context).colorScheme.onPrimary;

    return Row(
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          if (i > 0)
            // The connector sits between markers and fills once the previous
            // stage completes, so the line carries the progress too.
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i <= step ? accent : idle,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          _TimelineDot(
            done: i <= step,
            active: i == step,
            color: i <= step ? accent : idle,
            activeGlyphColor: activeColor,
          ),
        ],
      ],
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({
    required this.done,
    required this.active,
    required this.color,
    required this.activeGlyphColor,
  });

  final bool done;
  final bool active;
  final Color color;
  final Color activeGlyphColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.entrance,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? color : Colors.transparent,
        border: Border.all(color: color, width: done ? 0 : 1.5),
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 8)]
            : null,
      ),
      child: done
          ? Icon(
              AppIcons.success,
              size: 12,
              color: activeGlyphColor,
              weight: 600,
            )
          : null,
    );
  }
}

/// Compact build stamp. Deliberately quiet — it is metadata, not content.
class VersionBadge extends StatelessWidget {
  final bool compact;
  final bool light;
  const VersionBadge({super.key, this.compact = false, this.light = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        final version = info?.version ?? '1.0.0';
        final build = info?.buildNumber ?? '1';
        final text = compact ? 'v$version' : 'v$version · $build';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.info,
              size: 12,
              color: light ? GossColors.darkTextMuted : context.mutedColor,
            ),
            const SizedBox(width: Insets.xxs + 1),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: light ? GossColors.darkTextMuted : context.mutedColor,
                fontSize: TypeScale.micro,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        );
      },
    );
  }
}

class ExportButtons extends StatelessWidget {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  const ExportButtons({
    super.key,
    required this.title,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<AppProvider>().isArabic;
    return Wrap(
      spacing: Insets.xs,
      runSpacing: Insets.xs,
      children: [
        _exportTile(
          context: context,
          icon: AppIcons.print,
          label: 'PDF',
          tone: IconTone.danger,
          onTap: () => _run(
            context,
            isArabic: isArabic,
            job: () => ExportService.exportPdf(
              title: title,
              headers: headers,
              rows: rows,
              isArabic: isArabic,
            ),
            msg: 'PDF',
          ),
        ),
        _exportTile(
          context: context,
          icon: AppIcons.download,
          label: 'Excel',
          tone: IconTone.success,
          onTap: () => _run(
            context,
            isArabic: isArabic,
            job: () => ExportService.exportExcel(
              sheetName: title,
              headers: headers,
              rows: rows,
              isArabic: isArabic,
            ),
            msg: 'Excel',
          ),
        ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context, {
    required bool isArabic,
    required Future<void> Function() job,
    required String msg,
  }) async {
    try {
      await job();
    } catch (e) {
      if (!context.mounted) return;
      final short = (e.toString().trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تعذر إنشاء ملف $msg. $short'
                : 'Failed to create the $msg file. $short',
          ),
        ),
      );
    }
  }

  /// A compact outlined action consistent with the new button system: 12px
  /// radius, a hairline border and a tinted glyph rather than a saturated fill.
  Widget _exportTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required IconTone tone,
    required VoidCallback onTap,
  }) {
    final color = switch (tone) {
      IconTone.danger => context.dangerColor,
      IconTone.success => context.successColor,
      _ => Theme.of(context).colorScheme.primary,
    };

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        height: ControlSize.sm - 2,
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Corners.md),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: IconSize.inline, color: color, weight: 500),
            const SizedBox(width: Insets.xs - 2),
            Text(
              label,
              style: TextStyle(
                fontSize: TypeScale.caption,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The application's standard action button.
///
/// A rounded rectangle at a 12px radius rather than a pill, available in three
/// visual weights so a screen can express hierarchy without reaching for
/// `ElevatedButton` directly.
enum ButtonVariant {
  /// Filled accent — the single primary action in a view.
  primary,

  /// Outlined with an accent label — secondary actions.
  secondary,

  /// Flat tonal fill — tertiary or repeated actions.
  tonal,
}

class GossButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isSmall;
  final IconData? icon;
  final ButtonVariant variant;
  final bool expand;

  const GossButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.isSmall = false,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final accent = color ?? Theme.of(context).colorScheme.primary;

    // A custom colour on a primary button implies intent, so it stays filled;
    // otherwise the requested variant decides.
    final style = switch (variant) {
      ButtonVariant.primary => ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: context.isDarkMode
            ? const Color(0xFF061018)
            : Colors.white,
        disabledBackgroundColor: accent.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
      ),
      ButtonVariant.secondary => ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: accent,
        disabledForegroundColor: accent.withValues(alpha: 0.35),
        side: BorderSide(color: accent.withValues(alpha: enabled ? 0.4 : 0.15)),
      ),
      ButtonVariant.tonal => ElevatedButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.12),
        foregroundColor: accent,
        disabledForegroundColor: accent.withValues(alpha: 0.30),
        elevation: 0,
      ),
    };

    final height =
        (isSmall ? ControlSize.sm : ControlSize.md) * context.goss.density;

    return Opacity(
      opacity: enabled ? 1 : 0.75,
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: ElevatedButton(
          onPressed: onPressed,
          style: style.copyWith(
            minimumSize: WidgetStatePropertyAll(Size(0, height)),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(
                horizontal:
                    (isSmall ? Insets.sm + 2 : Insets.lg) *
                    context.goss.density,
                vertical: 0,
              ),
            ),
            elevation: const WidgetStatePropertyAll(0),
            textStyle: WidgetStatePropertyAll(
              TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isSmall ? TypeScale.caption : TypeScale.body,
                letterSpacing: 0.1,
              ),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Corners.md),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: isSmall ? 15 : IconSize.inline, weight: 500),
                SizedBox(width: isSmall ? Insets.xs - 2 : Insets.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section heading.
///
/// Now a compact 16px label with a hairline rule rather than a 28px display
/// face, which is what lets a long content page keep its vertical budget for
/// content.
class SectionTitle extends StatelessWidget {
  final String title;
  final bool isArabic;
  final Widget? trailing;

  const SectionTitle({
    super.key,
    required this.title,
    required this.isArabic,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: TypeScale.sectionTitle,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: context.headingColor,
              ),
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Insets.xs),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A compact page introduction.
///
/// This replaces the old 96px gradient hero. It is now a slim title band: one
/// line of type on a tinted surface with a hairline bottom border, capped at a
/// fixed small height so the content beneath starts immediately. The gradient
/// is gone — the brand colour now comes from the accent rule and the title.
class PageHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isArabic;

  const PageHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: context.constrain(
        Padding(
          // Deliberately tight: roughly 64-72dp total including the subtitle.
          padding: EdgeInsets.symmetric(
            horizontal: context.goss.pagePadding,
            vertical: Insets.sm + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // A short accent bar reads as branding without the weight of
                  // a large coloured block.
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: FlexibleText(
                      title,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: TypeScale.pageTitle,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: context.headingColor,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
              if (subtitle.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: 3,
                    start: Insets.sm + 3,
                  ),
                  child: FlexibleText(
                    subtitle,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      height: 1.35,
                      color: context.mutedColor,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final bool isArabic;
  final VoidCallback? onAdd;
  final Widget? child;

  const ProductCard({
    super.key,
    required this.product,
    required this.isArabic,
    this.onAdd,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(Insets.md * context.goss.density),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A small tinted glyph anchors the card without the weight of
                // an image placeholder.
                IconContainer(
                  icon: AppIcons.products,
                  tone: IconTone.primary,
                  size: 32,
                  iconSize: 16,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FlexibleText(
                        isArabic ? product.nameAr : product.nameEn,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: TypeScale.cardTitle,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                          color: context.headingColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FlexibleText(
                        isArabic ? product.descAr : product.descEn,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          height: 1.35,
                          color: context.mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Container(height: 1, color: context.borderColor),
            const SizedBox(height: Insets.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Price is the figure a buyer scans for, so it leads the row.
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: product.price, end: product.price),
                    duration: Motion.normal,
                    curve: Motion.entrance,
                    builder: (context, value, _) => Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value.toStringAsFixed(2),
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${isArabic ? 'ج.م' : 'EGP'} / ${product.unit}',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: TypeScale.micro,
                            fontWeight: FontWeight.w500,
                            color: context.mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onAdd != null)
                  GossButton(
                    label: isArabic ? 'إضافة' : 'Add',
                    icon: AppIcons.add,
                    onPressed: onAdd,
                    isSmall: true,
                    variant: ButtonVariant.secondary,
                  ),
              ],
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

/// Animated (frame-by-frame) GOSST logo used on the app loading screen.
/// The frames are exported from the official .webm loop and bundled under
/// `assets/anim_logo/` (frame_01..frame_46 at ~30fps = ~1.5s loop).
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key, this.size = 160});

  final double size;

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> {
  static const int _frameCount = 46;
  static const Duration _framePeriod = Duration(milliseconds: 33);

  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    // Pre-decode every frame up front so the first loop plays smoothly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (var i = 1; i <= _frameCount; i++) {
        final asset = AssetImage(
          'assets/anim_logo/frame_${i.toString().padLeft(2, '0')}.png',
        );
        unawaited(precacheImage(asset, context));
      }
    });
    _timer = Timer.periodic(_framePeriod, (_) {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % _frameCount);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = (_frame + 1).toString().padLeft(2, '0');
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.asset(
        'assets/anim_logo/frame_$frame.png',
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );
  }
}
