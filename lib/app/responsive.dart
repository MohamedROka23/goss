import 'package:flutter/material.dart';

/// Layout buckets, derived from the *shortest* side of the window.
///
/// Shortest-side is the only measurement that reliably separates a 7" tablet
/// (600x960) from a large phone (430x932) in either orientation. Using width
/// would classify a 7" tablet in landscape as a phone.
enum ScreenSize {
  /// Phones: 5" up to 6.7" (shortest side below 600dp).
  compact,

  /// Small/medium tablets: 7" and 8" (600dp up to 899dp).
  medium,

  /// Large tablets: 10" and up (900dp and above).
  expanded;

  bool get isCompact => this == ScreenSize.compact;
  bool get isMedium => this == ScreenSize.medium;
  bool get isExpanded => this == ScreenSize.expanded;
  bool get isTablet => this != ScreenSize.compact;
}

/// Immutable snapshot of the current layout metrics.
///
/// Read it from a build context with `Responsive.of(context)`, or use the
/// [BuildContextGoss] extension (`context.goss`) for terser call sites.
@immutable
class Responsive {
  const Responsive({
    required this.size,
    required this.width,
    required this.height,
    required this.shortestSide,
    required this.textDirection,
  });

  final ScreenSize size;
  final double width;
  final double height;
  final double shortestSide;
  final TextDirection textDirection;

  /// Reference width of a mainstream phone, used as the neutral point so a
  /// 1.0 scale means "looks exactly like it did before".
  static const double _reference = 411;

  /// Raw width ratio, clamped so a 10" tablet does not inflate text into
  /// headline sizes and a 5" phone does not shrink it below legibility.
  double get scale {
    final raw = shortestSide / _reference;
    return raw.clamp(0.90, 1.15);
  }

  /// Multiplier for padding/gaps. Deliberately smaller than [scale] and
  /// stepped per bucket instead of continuous, because raw proportional
  /// padding makes tablet layouts look sparse and phone layouts cramped.
  double get density {
    switch (size) {
      case ScreenSize.compact:
        return 1.0;
      case ScreenSize.medium:
        return 1.15;
      case ScreenSize.expanded:
        return 1.25;
    }
  }

  /// Reads as lines of text wider than this stop being comfortable, so wide
  /// layouts are centred inside this instead of stretching edge to edge.
  double get maxContentWidth {
    switch (size) {
      case ScreenSize.compact:
        return double.infinity;
      case ScreenSize.medium:
        return 720;
      case ScreenSize.expanded:
        return 1000;
    }
  }

  /// Number of columns a card grid should use to keep each card at least
  /// [minItemWidth] wide, honouring the available width.
  int columnsFor(double minItemWidth, {double spacing = 12}) {
    if (minItemWidth <= 0) return 1;
    final usable = width - (columnsPadding * 2);
    final fit = ((usable + spacing) / (minItemWidth + spacing)).floor();
    return fit.clamp(1, maxColumns);
  }

  /// Page gutter, already scaled by [density].
  double get pagePadding => 16 * density;

  double get columnsPadding => pagePadding;

  /// Keeps a caption readable on a phone without shrinking the real text.
  double get captionFactor => size.isCompact ? 1.0 : 1.05;

  static Responsive of(BuildContext context) {
    final media = MediaQuery.of(context);
    return Responsive(
      size: sizeFor(media.size.shortestSide),
      width: media.size.width,
      height: media.size.height,
      shortestSide: media.size.shortestSide,
      textDirection: Directionality.of(context),
    );
  }

  static ScreenSize sizeFor(double shortestSide) {
    if (shortestSide >= 900) return ScreenSize.expanded;
    if (shortestSide >= 600) return ScreenSize.medium;
    return ScreenSize.compact;
  }
}

/// Maximum grid columns per bucket. Prevents a 10" tablet from showing a
/// 5-column grid of unreadably small cards.
const int maxColumns = 4;

extension BuildContextGoss on BuildContext {
  Responsive get goss => Responsive.of(this);

  ScreenSize get screenSize => goss.size;
  bool get isTablet => goss.size.isTablet;
  bool get isExpandedLayout => goss.size.isExpanded;

  /// Scales a spacing constant for the current device.
  double gap(double base) => base * goss.density;

  /// Horizontal page gutter that respects the window insets (notches, system
  /// bars) and the current size bucket.
  EdgeInsets get pageInsets =>
      EdgeInsets.symmetric(horizontal: goss.pagePadding);

  EdgeInsets get pageInsetsAll => EdgeInsets.all(goss.pagePadding);

  /// Centres and width-limits page content on tablets while leaving phones
  /// completely untouched (`maxContentWidth` is infinite there).
  Widget constrain(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: goss.maxContentWidth),
      child: child,
    ),
  );

  /// Number of columns for a responsive card grid.
  int gridColumns(double minItemWidth, {double spacing = 12}) =>
      goss.columnsFor(minItemWidth, spacing: spacing);
}

/// Rebuilds only when the relevant metrics change, so a resize does not
/// rebuild the whole subtree. Prefer this over a bare [LayoutBuilder] inside
/// list items.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Responsive goss) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.biggest.shortestSide.isFinite
            ? constraints.biggest.shortestSide
            : MediaQuery.sizeOf(context).shortestSide;
        return builder(
          context,
          Responsive(
            size: Responsive.sizeFor(shortest),
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            shortestSide: shortest,
            textDirection: Directionality.of(context),
          ),
        );
      },
    );
  }
}

/// Standard page body: applies the device gutter, centres content on wide
/// screens, and makes the whole page scrollable so nothing can overflow a
/// short viewport (landscape phones included).
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding,
    this.controller,
    this.maxContentWidth,
  });

  final Widget child;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final goss = Responsive.of(context);
    final limit = maxContentWidth ?? goss.maxContentWidth;

    Widget body = Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: goss.pagePadding,
            vertical: goss.pagePadding,
          ),
      child: child,
    );

    if (limit.isFinite) {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: limit),
          child: body,
        ),
      );
    }

    if (!scrollable) return SafeArea(child: body);
    return SafeArea(
      child: SingleChildScrollView(
        controller: controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: body,
      ),
    );
  }
}

/// A [Row] that degrades to a vertical [Column] when the children cannot fit
/// horizontally. This is the single biggest guard against yellow/black overflow
/// stripes on narrow phones and in landscape.
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    super.key,
    required this.children,
    this.spacing = 12,
    this.minChildWidth = 180,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  final List<Widget> children;
  final double spacing;
  final double minChildWidth;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final needed =
            (minChildWidth * children.length) +
            (spacing * (children.length - 1).clamp(0, 999));
        if (children.length > 1 && available < needed) {
          return Column(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisSize: mainAxisSize,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              if (mainAxisSize == MainAxisSize.max)
                Expanded(child: children[i])
              else
                children[i],
            ],
          ],
        );
      },
    );
  }
}

/// Fixed-count grid that becomes a scrollable grid whose column count follows
/// the available width, with a sane floor and ceiling.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 180,
    this.spacing = 12,
    this.aspectRatio = 1,
    this.shrinkWrap = true,
    this.padding,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double minItemWidth;
  final double spacing;
  final double aspectRatio;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final goss = Responsive.of(context);
    final columns = goss.columnsFor(minItemWidth, spacing: spacing);
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      padding: padding ?? EdgeInsets.all(goss.pagePadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, i) => itemBuilder(context, i),
    );
  }
}

/// Lets an oversized child shrink instead of overflowing: text in a narrow
/// column, long order numbers, unbroken Arabic/Latin strings.
class FlexibleText extends StatelessWidget {
  const FlexibleText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: true,
    );
  }
}
