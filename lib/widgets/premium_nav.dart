import 'package:flutter/material.dart';

import '../app/icons.dart';
import '../app/motion.dart';
import '../app/responsive.dart';
import '../app/spacing.dart';
import '../app/theme.dart';
import 'premium_header.dart';

/// One destination in the application's navigation.
@immutable
class NavDestination {
  const NavDestination({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badge,
    this.tone = IconTone.primary,
  });

  /// Stable key the parent uses to map a selection back to a screen.
  final String id;
  final String label;
  final IconData icon;

  /// Optional filled/solid variant shown while selected, when the set has one.
  final IconData? selectedIcon;
  final int? badge;
  final IconTone tone;

  int? get resolvedBadge => (badge == null || badge! <= 0) ? null : badge;
}

/// Which chrome a shell should present for the current window.
///
/// The brief asks for a rail or sidebar once there is horizontal room, and for
/// a bottom bar otherwise. The decision is made once, in layout, so both the
/// shell and its children can rely on it.
enum NavLayout {
  /// Bottom bar: the window is too narrow to afford a rail.
  bottomBar,

  /// Icon-only rail with a divider between primary and secondary groups.
  rail,

  /// Full sidebar with labels, group headings and a footer slot.
  sidebar,
}

/// Chooses the navigation chrome for a given available width.
///
/// 720dp is the breakpoint: below it a labelled sidebar would crowd the
/// content, and a bottom bar is the platform expectation. Above it the content
/// pane is wide enough to give navigation its own column.
NavLayout navLayoutFor(double width) {
  if (width < 720) return NavLayout.bottomBar;
  if (width < 1040) return NavLayout.rail;
  return NavLayout.sidebar;
}

/// The shared navigation surface.
///
/// Renders as a bottom bar, an icon rail or a full sidebar depending on
/// [layout], but keeps one selection model, one item geometry and one selected
/// treatment across all three, so switching orientation never changes the
/// product's identity.
class PremiumNav extends StatelessWidget {
  const PremiumNav({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onSelected,
    required this.layout,
    this.secondary = const [],
    this.footer,
    this.brand,
  });

  final List<NavDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final NavLayout layout;

  /// Destinations placed below a divider, matching the reference's split
  /// between the primary module list and the account group.
  final List<NavDestination> secondary;

  /// Optional control rendered at the bottom of a rail or sidebar.
  final Widget? footer;

  /// Optional brand mark shown at the top of a rail or sidebar.
  final Widget? brand;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      NavLayout.bottomBar => _BottomBar(
        destinations: destinations,
        selectedId: selectedId,
        onSelected: onSelected,
      ),
      NavLayout.rail => _Rail(
        destinations: destinations,
        secondary: secondary,
        selectedId: selectedId,
        onSelected: onSelected,
        brand: brand,
        footer: footer,
      ),
      NavLayout.sidebar => _Sidebar(
        destinations: destinations,
        secondary: secondary,
        selectedId: selectedId,
        onSelected: onSelected,
        brand: brand,
        footer: footer,
      ),
    };
  }
}

/// Selected state shared by all three layouts: a low-alpha accent fill plus an
/// accent-coloured glyph and label. Never a large solid block.
class _SelectedSkin extends StatelessWidget {
  const _SelectedSkin({
    required this.selected,
    required this.borderRadius,
    required this.child,
  });

  final bool selected;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.entrance,
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _NavGlyph extends StatelessWidget {
  const _NavGlyph({
    required this.destination,
    required this.selected,
    this.size = IconSize.nav,
  });

  final NavDestination destination;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final color = selected
        ? accent
        : (context.isDarkMode
              ? GossColors.darkTextSecondary
              : GossColors.lightTextSecondary);

    final icon = selected && destination.selectedIcon != null
        ? destination.selectedIcon!
        : destination.icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: size, color: color, weight: selected ? 600 : 500),
        if (destination.resolvedBadge != null)
          PositionedDirectional(
            top: -3,
            end: -6,
            child: _Badge(count: destination.resolvedBadge!),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontSize: 9,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: context.isDarkMode ? const Color(0xFF061018) : Colors.white,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.destinations,
    required this.selectedId,
    required this.onSelected,
  });

  final List<NavDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // A hairline top border keeps the bar off the content without a shadow.
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (final d in destinations)
                Expanded(
                  child: _BottomBarItem(
                    destination: d,
                    selected: d.id == selectedId,
                    onTap: () => onSelected(d.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SelectedSkin(
              selected: selected,
              borderRadius: BorderRadius.circular(Corners.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: 3,
                ),
                child: _NavGlyph(destination: destination, selected: selected),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? accent : context.mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.destinations,
    required this.secondary,
    required this.selectedId,
    required this.onSelected,
    this.brand,
    this.footer,
  });

  final List<NavDestination> destinations;
  final List<NavDestination> secondary;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final Widget? brand;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: BorderDirectional(end: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            if (brand != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                child: brand,
              ),
            const SizedBox(height: Insets.xxs),
            for (final d in destinations)
              _RailItem(
                destination: d,
                selected: d.id == selectedId,
                onTap: () => onSelected(d.id),
              ),
            // A divider between the module list and the account group, which
            // is what gives the rail its two clear halves.
            if (secondary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.xs,
                ),
                child: SectionDivider(padding: EdgeInsets.zero),
              ),
            for (final d in secondary)
              _RailItem(
                destination: d,
                selected: d.id == selectedId,
                onTap: () => onSelected(d.id),
              ),
            const Spacer(),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: destination.label,
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: PressableScale(
          onTap: onTap,
          pressedScale: 0.9,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: 3,
            ),
            child: _SelectedSkin(
              selected: selected,
              borderRadius: BorderRadius.circular(Corners.md),
              child: SizedBox(
                height: ControlSize.sm,
                child: Center(
                  child: _NavGlyph(
                    destination: destination,
                    selected: selected,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.secondary,
    required this.selectedId,
    required this.onSelected,
    this.brand,
    this.footer,
  });

  final List<NavDestination> destinations;
  final List<NavDestination> secondary;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final Widget? brand;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: BorderDirectional(end: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (brand != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.md,
                  Insets.md,
                  Insets.md,
                ),
                child: brand,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final d in destinations)
                    _SidebarItem(
                      destination: d,
                      selected: d.id == selectedId,
                      onTap: () => onSelected(d.id),
                    ),
                  if (secondary.isNotEmpty)
                    const SectionDivider(label: 'Account'),
                  for (final d in secondary)
                    _SidebarItem(
                      destination: d,
                      selected: d.id == selectedId,
                      onTap: () => onSelected(d.id),
                    ),
                  const SizedBox(height: Insets.md),
                ],
              ),
            ),
            if (footer != null)
              Padding(padding: const EdgeInsets.all(Insets.sm), child: footer),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.985,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _SelectedSkin(
            selected: selected,
            borderRadius: BorderRadius.circular(Corners.md),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              child: Row(
                children: [
                  _NavGlyph(
                    destination: destination,
                    selected: selected,
                    size: IconSize.nav,
                  ),
                  const SizedBox(width: Insets.sm + 2),
                  Expanded(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: TypeScale.body,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected ? accent : context.bodyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays out a shell as navigation plus content, choosing the chrome for the
/// available width.
///
/// Content is keyed by the selected destination so a switch animates through
/// [FadeSwitcher] rather than snapping, which keeps the transition consistent
/// with the rest of the product.
class PremiumShellLayout extends StatelessWidget {
  const PremiumShellLayout({
    super.key,
    required this.nav,
    required this.selectedId,
    required this.content,
    this.secondary = const [],
    this.navFooter,
    this.brand,
    this.onSelectSecondary,
  });

  /// The navigation widget, rebuilt for whichever layout is chosen.
  final PremiumNav Function(NavLayout layout) nav;

  final String selectedId;
  final Widget content;
  final List<NavDestination> secondary;
  final Widget? navFooter;
  final Widget? brand;

  /// Called instead of [nav]'s handler for secondary destinations, so a shell
  /// can route those to actions rather than pages.
  final ValueChanged<String>? onSelectSecondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = navLayoutFor(constraints.maxWidth);

        if (layout == NavLayout.bottomBar) {
          return Scaffold(body: content, bottomNavigationBar: nav(layout));
        }

        return Scaffold(
          body: Row(
            children: [
              nav(layout),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: context.borderColor,
              ),
              Expanded(
                child: FadeSwitcher(
                  child: KeyedSubtree(
                    key: ValueKey('shell-$selectedId'),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
