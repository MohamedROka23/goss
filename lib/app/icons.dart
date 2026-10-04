import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'spacing.dart';

/// The application's single icon vocabulary.
///
/// Every icon in the app resolves through this map, which is what guarantees
/// one coherent family instead of a mix of styles drifting screen by screen.
/// The set is Lucide: geometric construction, a 2px outline, rounded caps and
/// joins — the language the redesign calls for.
///
/// Directional icons use the `matchTextDirection` variants where Lucide ships
/// them, so a "next" arrow points the correct way in Arabic without any
/// per-screen RTL branching.
abstract final class AppIcons {
  const AppIcons._();

  // ── Navigation and structure ────────────────────────────────────────
  static const IconData dashboard = LucideIcons.layoutDashboard;
  static const IconData orders = LucideIcons.clipboardList;
  static const IconData tracking = LucideIcons.truck;
  static const IconData customers = LucideIcons.users;
  static const IconData products = LucideIcons.package;
  static const IconData catalog = LucideIcons.packageSearch;
  static const IconData quotes = LucideIcons.receipt;
  static const IconData purchases = LucideIcons.shoppingCart;
  static const IconData accounting = LucideIcons.wallet;
  static const IconData expenses = LucideIcons.banknote;
  static const IconData profit = LucideIcons.chartColumn;
  static const IconData ledger = LucideIcons.landmark;
  static const IconData team = LucideIcons.userRound;
  static const IconData settings = LucideIcons.settings;
  static const IconData notifications = LucideIcons.bell;
  static const IconData chat = LucideIcons.messageSquare;
  static const IconData home = LucideIcons.house;
  static const IconData logistics = LucideIcons.warehouse;
  static const IconData supplies = LucideIcons.boxes;
  static const IconData about = LucideIcons.info;
  static const IconData contact = LucideIcons.mail;
  static const IconData services = LucideIcons.grid2x2;
  static const IconData profile = LucideIcons.circleUser;
  static const IconData support = LucideIcons.lifeBuoy;

  // ── Actions ──────────────────────────────────────────────────────────
  static const IconData add = LucideIcons.plus;
  static const IconData edit = LucideIcons.pencil;
  static const IconData delete = LucideIcons.trash2;
  static const IconData search = LucideIcons.search;
  static const IconData filter = LucideIcons.slidersHorizontal;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData download = LucideIcons.download;
  static const IconData upload = LucideIcons.upload;
  static const IconData share = LucideIcons.share2;
  static const IconData more = LucideIcons.ellipsis;
  static const IconData print = LucideIcons.printer;
  static const IconData menu = LucideIcons.menu;
  static const IconData close = LucideIcons.x;
  static const IconData send = LucideIcons.send;
  static const IconData attach = LucideIcons.paperclip;
  static const IconData archive = LucideIcons.archive;
  static const IconData restore = LucideIcons.archiveRestore;

  // ── Directional (flip in RTL) ────────────────────────────────────────
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData forward = LucideIcons.arrowRight;
  static const IconData backAuto = LucideIcons.arrowLeftDir;
  static const IconData forwardAuto = LucideIcons.arrowRightDir;
  static const IconData chevronLeftAuto = LucideIcons.chevronLeftDir;
  static const IconData chevronRightAuto = LucideIcons.chevronRightDir;

  // ── Status and feedback ──────────────────────────────────────────────
  static const IconData success = LucideIcons.circleCheck;
  static const IconData pending = LucideIcons.clock;
  static const IconData warning = LucideIcons.triangleAlert;
  static const IconData error = LucideIcons.circleX;
  static const IconData info = LucideIcons.info;

  // ── Security ─────────────────────────────────────────────────────────
  static const IconData shield = LucideIcons.shieldCheck;
  static const IconData lock = LucideIcons.lock;
  static const IconData fingerprint = LucideIcons.fingerprint;
  static const IconData scan = LucideIcons.scanLine;
  static const IconData signOut = LucideIcons.logOut;

  // ── Theme and locale ─────────────────────────────────────────────────
  static const IconData sun = LucideIcons.sun;
  static const IconData moon = LucideIcons.moon;
  static const IconData language = LucideIcons.globe;
  static const IconData palette = LucideIcons.palette;

  // ── Empty states ─────────────────────────────────────────────────────
  static const IconData emptyBox = LucideIcons.packageOpen;
  static const IconData emptyInbox = LucideIcons.inbox;
  static const IconData emptySearch = LucideIcons.searchX;

  // ── Misc ─────────────────────────────────────────────────────────────
  static const IconData calendar = LucideIcons.calendar;
  static const IconData camera = LucideIcons.camera;
  static const IconData image = LucideIcons.image;
  static const IconData location = LucideIcons.mapPin;
  static const IconData phone = LucideIcons.phone;
  static const IconData mail = LucideIcons.mail;
  static const IconData tag = LucideIcons.tag;
  static const IconData layers = LucideIcons.layers;
  static const IconData list = LucideIcons.listChecks;
  static const IconData zap = LucideIcons.zap;
  static const IconData eye = LucideIcons.eye;
  static const IconData star = LucideIcons.star;
  static const IconData sparkle = LucideIcons.sparkles;
}

/// Icon containers: a compact tinted tile that gives an icon a consistent,
/// slightly premium home without turning it into a glowing box.
///
/// Tones mirror the colour system — cyan for technology and active states,
/// burgundy for brand emphasis, plus the semantic status tones.
enum IconTone {
  /// Cyan — the default interactive accent.
  primary,

  /// Burgundy — brand identity and important actions.
  brand,

  /// Neutral — secondary content, no colour emphasis.
  neutral,

  /// Success.
  success,

  /// Warning / preparing.
  warning,

  /// Danger / destructive.
  danger,

  /// Outlined with no fill — for low-emphasis decorative placement.
  bare,
}

/// A tinted icon container.
///
/// Sized 24–44 with an 10–12 radius and a very low-alpha tint, which is what
/// makes a row of icons read as one designed set rather than loose glyphs.
class IconContainer extends StatelessWidget {
  const IconContainer({
    super.key,
    required this.icon,
    this.tone = IconTone.primary,
    this.size = 36,
    this.iconSize,
    this.border = true,
  });

  final IconData icon;
  final IconTone tone;

  /// Outer edge of the tile. The default is a touch above the inline icon size
  /// so the glyph has breathing room without becoming a button.
  final double size;

  /// Overrides the glyph size; defaults to roughly half the tile.
  final double? iconSize;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color fg, Color bg, Color borderColor) = switch (tone) {
      IconTone.primary => (
        scheme.primary,
        scheme.primary.withValues(alpha: isDark ? 0.10 : 0.12),
        scheme.primary.withValues(alpha: isDark ? 0.22 : 0.26),
      ),
      IconTone.brand => (
        // The brand tone is now a lighter sibling of the primary cyan, so
        // brand containers read as cyan-family rather than a second hue.
        scheme.primary,
        scheme.primary.withValues(alpha: isDark ? 0.16 : 0.12),
        scheme.primary.withValues(alpha: isDark ? 0.34 : 0.28),
      ),
      IconTone.neutral => (
        const Color(0xFF94A3B8),
        const Color(0xFF94A3B8).withValues(alpha: isDark ? 0.08 : 0.10),
        const Color(0xFF94A3B8).withValues(alpha: isDark ? 0.16 : 0.22),
      ),
      IconTone.success => (
        const Color(0xFF22C55E),
        const Color(0xFF22C55E).withValues(alpha: isDark ? 0.10 : 0.12),
        const Color(0xFF22C55E).withValues(alpha: isDark ? 0.24 : 0.28),
      ),
      IconTone.warning => (
        const Color(0xFFF59E0B),
        const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.10 : 0.12),
        const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.24 : 0.28),
      ),
      IconTone.danger => (
        const Color(0xFFEF4444),
        const Color(0xFFEF4444).withValues(alpha: isDark ? 0.10 : 0.12),
        const Color(0xFFEF4444).withValues(alpha: isDark ? 0.24 : 0.28),
      ),
      IconTone.bare => (
        const Color(0xFF94A3B8),
        Colors.transparent,
        Colors.transparent,
      ),
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: border && tone != IconTone.bare
            ? Border.all(color: borderColor, width: 1)
            : null,
      ),
      child: Icon(
        icon,
        size: iconSize ?? (size * 0.5),
        color: fg,
        // The family is an outline face; a weight nudge keeps it legible
        // against tinted backgrounds without looking heavy.
        weight: 500,
      ),
    );
  }
}

/// Convenience: an icon container sized for inline use in a list row.
class InlineIcon extends StatelessWidget {
  const InlineIcon({
    super.key,
    required this.icon,
    this.tone = IconTone.neutral,
    this.size = 32,
  });

  final IconData icon;
  final IconTone tone;
  final double size;

  @override
  Widget build(BuildContext context) => IconContainer(
    icon: icon,
    tone: tone,
    size: size,
    iconSize: IconSize.inline,
  );
}

/// Unused import guard: `spacing` is referenced by the icon size defaults above
/// in downstream widgets; keeping the reference explicit avoids an unused
// import lint if those widgets move files.
const double _keepSpacingReference = Insets.xs + IconSize.inline;
