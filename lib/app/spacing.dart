/// Spacing scale.
///
/// Every gap, pad and inset in the redesign comes from this ladder. Keeping a
/// single scale is what stops a codebase from drifting into arbitrary values
/// like 13 or 27 that look fine in isolation but read as noise across a screen.
abstract final class Insets {
  const Insets._();

  /// 4 — hairline gaps, icon-to-label spacing inside a row.
  static const double xxs = 4;

  /// 8 — gaps between related elements (chip group, label to field).
  static const double xs = 8;

  /// 12 — inner card padding on dense cards, list item vertical padding.
  static const double sm = 12;

  /// 16 — the default page gutter and standard card padding.
  static const double md = 16;

  /// 20 — roomy card padding and section separation on mobile.
  static const double lg = 20;

  /// 24 — between major sections.
  static const double xl = 24;

  /// 32 — between top-level blocks on a wide layout.
  static const double xxl = 32;

  /// 48 — reserved for empty states so they sit optically centred.
  static const double section = 48;
}

/// Corner radii.
///
/// Deliberately *not* pills: the brief calls for rounded rectangles, so the
/// radius stays a fixed number rather than half the height.
abstract final class Corners {
  const Corners._();

  /// 8 — small chips and icon tiles.
  static const double sm = 8;

  /// 12 — buttons and inputs.
  static const double md = 12;

  /// 16 — standard cards.
  static const double lg = 16;

  /// 20 — feature cards and panels.
  static const double xl = 20;

  /// 28 — dialogs and sheets.
  static const double sheet = 28;
}

/// Control heights, so a button, an input and a nav item all share a rhythm.
abstract final class ControlSize {
  const ControlSize._();

  /// 40 — icon buttons and compact list rows.
  static const double sm = 40;

  /// 46 — the standard control height: buttons, inputs, nav items.
  static const double md = 46;

  /// 52 — primary actions on touch-first screens.
  static const double lg = 52;
}

/// Type scale. Kept deliberately small: the brief warns against oversized type,
/// and every step here is small enough to keep a dense list readable.
abstract final class TypeScale {
  const TypeScale._();

  static const double pageTitle = 20;
  static const double sectionTitle = 16;
  static const double cardTitle = 15;
  static const double body = 14;
  static const double secondary = 13;
  static const double caption = 12;
  static const double micro = 11;

  /// Page titles and section headings.
  static const double headlineWeight = 700;

  /// Card titles and emphasised labels.
  static const double titleWeight = 600;

  /// Regular body copy.
  static const double bodyWeight = 400;
}

/// Icon sizes. Navigation sits at the small end; empty states use the large.
abstract final class IconSize {
  const IconSize._();

  static const double nav = 21;
  static const double action = 20;
  static const double inline = 18;
  static const double hero = 44;
}
