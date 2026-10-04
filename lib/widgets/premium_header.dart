import 'package:flutter/material.dart';

import '../app/icons.dart';
import '../app/motion.dart';
import '../app/responsive.dart';
import '../app/spacing.dart';
import '../app/theme.dart';
import 'icon_3d.dart';

/// The application's compact premium header.
///
/// Replaces the default AppBar presentation. It is intentionally short — a
/// 58dp bar with a 1px bottom border and no elevation — so the content beneath
/// it starts almost immediately. Everything decorative that used to live in a
/// hero header has been removed; this carries navigation, a title, an optional
/// subtitle and actions, and nothing else.
///
/// [Adaptive] lets a parent widen the bar on tablets and desktop without
/// changing its contents.
class PremiumHeader extends StatelessWidget implements PreferredSizeWidget {
  const PremiumHeader({
    super.key,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.showBack = false,
    this.onBack,
    this.showDivider = true,
    this.height,
    this.padding,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;

  /// Overrides the default back affordance.
  final Widget? leading;

  /// Shows a back affordance. Ignored when [leading] is supplied.
  final bool showBack;
  final VoidCallback? onBack;

  final bool showDivider;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Size get preferredSize => Size.fromHeight(height ?? 58);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final accent = Theme.of(context).colorScheme.primary;

    // A hairline bottom border is what separates the bar from the page on a
    // dark ground, where a shadow would be invisible.
    final divider = showDivider
        ? Container(height: 1, color: context.borderColor)
        : const SizedBox.shrink();

    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: showDivider
            ? Border(bottom: BorderSide(color: context.borderColor))
            : null,
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding:
                  padding ??
                  EdgeInsetsDirectional.only(start: Insets.md, end: Insets.sm),
              child: Row(
                children: [
                  if (leading != null)
                    leading!
                  else if (showBack)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: Insets.xxs,
                      ),
                      child: IconAction(
                        icon: AppIcons.backAuto,
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                        tone: IconTone.primary,
                      ),
                    ),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: TypeScale.pageTitle,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: context.headingColor,
                            ),
                          ),
                        if (subtitle != null && subtitle!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                height: 1.2,
                                color: isDark
                                    ? GossColors.darkTextSecondary
                                    : GossColors.lightTextSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.xs),
                  ...actions,
                ],
              ),
            ),
          ),
          divider,
        ],
      ),
    );
  }
}

/// A compact page title used inside a scrolling page rather than in the bar.
///
/// Lets a screen introduce itself without spending header height on it.
class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.md,
        Insets.md,
        Insets.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            IconContainer(
              icon: icon!,
              tone: IconTone.primary,
              size: 34,
              iconSize: 17,
            ),
            const SizedBox(width: Insets.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: TypeScale.sectionTitle,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.headingColor,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      height: 1.35,
                      color: context.mutedColor,
                    ),
                  ),
                ],
              ],
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

/// A thin rule with an optional leading label, used to separate groups inside a
/// settings-style page without spending a full section header on them.
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, this.label, this.padding});

  final String? label;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: context.borderColor),
    );

    if (label == null) {
      return Padding(
        padding: padding ?? const EdgeInsets.symmetric(vertical: Insets.sm),
        child: line,
      );
    }

    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.md, Insets.xs),
      child: Row(
        children: [
          Text(
            label!.toUpperCase(),
            style: TextStyle(
              fontSize: TypeScale.micro,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: context.mutedColor,
            ),
          ),
          const SizedBox(width: Insets.sm),
          line,
        ],
      ),
    );
  }
}
