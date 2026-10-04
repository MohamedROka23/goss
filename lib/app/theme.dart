import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'motion.dart';
import 'spacing.dart';

/// The application's colour system.
///
/// Structure: near-black surfaces are the foundation and cyan carries
/// interaction, active state and brand emphasis. The app is deliberately
/// monochrome-cyan rather than two-hue: the secondary tone is a lighter
/// sibling of the primary, so colour communicates state without a second
/// hue competing for attention.
class GossColors {
  const GossColors._();

  // ── Cyan: interaction and active state ────────────────────────────────
  static const Color cyan = Color(0xFF38BDF8);
  static const Color cyanBright = Color(0xFF22D3EE);
  static const Color cyanSoft = Color(0xFF67E8F9);
  static const Color cyanDeep = Color(0xFF0284C7);

  /// Tints used behind cyan content. Kept as real constants (rather than
  /// inline alpha) because several widgets and the theme both reference them.
  static const Color cyanTintDark = Color(0x1438BDF8);
  static const Color cyanTintLight = Color(0x1F38BDF8);

  // ── Secondary brand ─────────────────────────────────────────────────
  // Repointed from burgundy to the sky-cyan family at the client's request.
  // The three steps are kept distinct so the brand tone still reads as a
  // lighter sibling of the primary rather than collapsing into an exact
  // duplicate: `burgundy` is the primary cyan, `burgundyBright` is the soft
  // cyan above it, and `burgundyDeep` is the darker teal-cyan used where the
  // brand needs depth (gradients, pressed states).
  static const Color burgundy = cyan;
  static const Color burgundyDeep = Color(0xFF0E7490);
  static const Color burgundyBright = cyanSoft;

  static const Color burgundyTintDark = cyanTintDark;
  static const Color burgundyTintLight = cyanTintLight;

  // ── Dark surfaces ────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF080B12);
  static const Color darkBgAlt = Color(0xFF0D111A);
  static const Color darkSurface = Color(0xFF131923);
  static const Color darkElevated = Color(0xFF191F2B);
  static const Color darkBorder = Color(0xFF243041);

  // ── Light surfaces ───────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF6F8FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF0F4F8);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // ── Semantic status ──────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ── Text ─────────────────────────────────────────────────────────────
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // ── Request / order status palette ───────────────────────────────────
  // Semantics are unchanged from the original app; only the values moved to
  // the new system so chips read as one set.
  static const Color statusPending = cyan;
  static const Color statusReview = warning;
  static const Color statusPreparing = warning;
  static const Color statusArriving = Color(0xFF8B5CF6);
  static const Color statusDelivering = burgundyBright;
  static const Color statusDelivered = success;
  static const Color statusRejected = error;
  static const Color statusCancelled = darkTextMuted;
  static const Color statusNew = cyanBright;

  // ── Legacy aliases ───────────────────────────────────────────────────
  // Screens across the app still reference the older names. Mapping them onto
  // the new system keeps every one of those call sites compiling *and* on-palette
  // without a mass rename.
  static const Color blue = cyan;
  static const Color blueSoft = cyanSoft;
  static const Color blueDeep = cyanDeep;
  static const Color royal = cyanDeep;
  static const Color royalMid = cyan;
  static const Color pink = burgundyBright;
  static const Color pinkSoft = cyanTintLight;
  static const Color pinkDeep = burgundy;
  static const Color navy = burgundy;
  static const Color navy2 = burgundyDeep;
  static const Color brandBlue = cyan;

  static const Color red = error;
  static const Color redDeep = burgundy;
  static const Color redBright = burgundyBright;
  static const Color redSoft = Color(0x1FEF4444);
  static const Color green = success;
  static const Color amber = warning;
  static const Color teal = cyanSoft;

  static const Color ink = lightText;
  static const Color muted = lightTextSecondary;
  static const Color line = lightBorder;
  static const Color bg = lightBg;
  static const Color white = Color(0xFFFFFFFF);

  static const Color darkInk = darkText;
  static const Color darkMuted = darkTextSecondary;
  static const Color darkSurfaceAlt = darkBgAlt;
  static const Color darkCard = darkSurface;

  // ── Gradients ────────────────────────────────────────────────────────
  // Restrained on purpose: each one is used to separate two planes of the UI,
  // never as decoration on its own.
  /// Header and sidebar wash: a dark plane lifting slightly toward cyan.
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF111827), Color(0xFF0D111A)],
  );

  /// Brand plane: deep cyan into surface. Used on the role screen and the
  /// brand-toned surfaces only.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E7490), Color(0xFF0B3C5A)],
  );

  /// Cyan highlight used behind active navigation and primary emphasis.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF67E8F9), Color(0xFF0284C7)],
  );

  // ── Radii, mirrored from the spacing tokens ──────────────────────────
  static const double radiusSm = Corners.sm;
  static const double radiusMd = Corners.md;
  static const double radiusLg = Corners.lg;
  static const double radiusXl = Corners.xl;
  static const double radiusSheet = Corners.sheet;

  // ── Shadows ──────────────────────────────────────────────────────────
  // Dark mode gets almost no shadow: depth comes from surface steps and 1px
  // borders. The shadow that does exist is short and low-opacity.
  static List<BoxShadow> get softShadow => const [
    BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> get glowShadow => const [
    BoxShadow(color: Color(0x3338BDF8), blurRadius: 18, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> get darkSoftShadow => softShadow;

  // ── Icon tones ───────────────────────────────────────────────────────
  static const Map<String, List<Color>> iconGradients = {
    'blue': [cyanSoft, cyanDeep],
    'navy': [cyan, cyanDeep],
    'pink': [Color(0xFF67E8F9), Color(0xFF0E7490)],
    'red': [Color(0xFFF87171), Color(0xFF991B1B)],
    'green': [Color(0xFF6EE7A8), Color(0xFF15803D)],
    'amber': [Color(0xFFFBBF5C), Color(0xFFB45309)],
    'teal': [Color(0xFF67E8F9), Color(0xFF0E7490)],
    'violet': [Color(0xFFB9A5F7), Color(0xFF5B21B6)],
    'warm': [Color(0xFF67E8F9), Color(0xFF0E7490)],
    'gold': [Color(0xFFF2C879), Color(0xFF92700F)],
  };
}

/// Resolves the full token set for one brightness, so the theme builder and the
/// `context.*` helpers can never drift apart.
@immutable
class _Palette {
  const _Palette({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.danger,
    required this.brand,
    required this.accentTint,
    required this.fieldFill,
  });

  final Color bg;
  final Color surface;
  final Color raised;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color danger;
  final Color brand;
  final Color accentTint;
  final Color fieldFill;

  static _Palette dark() => const _Palette(
    bg: GossColors.darkBg,
    surface: GossColors.darkBgAlt,
    raised: GossColors.darkSurface,
    border: GossColors.darkBorder,
    text: GossColors.darkText,
    textSecondary: GossColors.darkTextSecondary,
    textMuted: GossColors.darkTextMuted,
    accent: GossColors.cyan,
    danger: GossColors.error,
    brand: GossColors.burgundyBright,
    accentTint: GossColors.cyanTintDark,
    fieldFill: GossColors.darkBgAlt,
  );

  static _Palette light() => const _Palette(
    bg: GossColors.lightBg,
    surface: GossColors.lightSurface,
    raised: GossColors.lightSurface,
    border: GossColors.lightBorder,
    text: GossColors.lightText,
    textSecondary: GossColors.lightTextSecondary,
    textMuted: GossColors.lightTextMuted,
    // The deeper cyan holds its contrast on a white ground where the
    // lighter one would wash out.
    accent: GossColors.cyanDeep,
    danger: GossColors.error,
    brand: GossColors.burgundy,
    accentTint: GossColors.cyanTintLight,
    fieldFill: GossColors.lightSurfaceAlt,
  );
}

ThemeData gossTheme({bool isArabic = false, bool dark = false}) {
  final isDark = dark;
  final p = isDark ? _Palette.dark() : _Palette.light();

  final base = ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    fontFamily: isArabic ? 'Dubai' : 'Segoe UI',
    fontFamilyFallback: isArabic
        ? const ['Dubai', 'Amiri', 'Noto Naskh Arabic', 'Arial']
        : const ['Segoe UI', 'Roboto', 'Arial'],
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: p.accent,
      secondary: p.brand,
      error: p.danger,
      surface: p.surface,
      onPrimary: isDark ? const Color(0xFF061018) : Colors.white,
      onSurface: p.text,
    ),
    scaffoldBackgroundColor: p.bg,
    splashFactory: InkRipple.splashFactory,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );

  return base.copyWith(
    // ── Typography ─────────────────────────────────────────────────────
    // Small, tightly-tracked headings. Oversized type is the fastest way to
    // make a dense product look like a marketing page.
    textTheme: base.textTheme
        .apply(bodyColor: p.text, displayColor: p.text)
        .copyWith(
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontSize: TypeScale.pageTitle,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: p.text,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontSize: TypeScale.sectionTitle,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: p.text,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontSize: TypeScale.cardTitle,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontSize: 15,
            height: 1.45,
            color: p.text,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontSize: TypeScale.body,
            height: 1.45,
            color: p.text,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            fontSize: TypeScale.caption,
            height: 1.4,
            color: p.textSecondary,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontSize: TypeScale.body,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          labelMedium: base.textTheme.labelMedium?.copyWith(
            fontSize: TypeScale.caption,
            fontWeight: FontWeight.w600,
            color: p.textSecondary,
          ),
          labelSmall: base.textTheme.labelSmall?.copyWith(
            fontSize: TypeScale.micro,
            letterSpacing: 0.2,
            color: p.textMuted,
          ),
        ),

    pageTransitionsTheme: gossPageTransitions(),

    // ── Iconography ────────────────────────────────────────────────────
    // A single weight knob keeps every glyph in the family visually equal. The
    // face is an outline set, so a nudge above regular keeps it from reading
    // thin on a tinted background.
    iconTheme: IconThemeData(
      color: p.textSecondary,
      size: IconSize.action,
      weight: 500,
    ),

    // ── App bar ────────────────────────────────────────────────────────
    // Compact by design: no elevation, a 1px bottom border, and a short
    // toolbar so content starts immediately underneath.
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 58,
      titleSpacing: Insets.md,
      leadingWidth: 44,
      iconTheme: IconThemeData(color: p.textSecondary, size: IconSize.action),
      actionsIconTheme: IconThemeData(
        color: p.textSecondary,
        size: IconSize.action,
      ),
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: TypeScale.pageTitle,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),

    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),

    // ── Cards ──────────────────────────────────────────────────────────
    // Lightweight: a raised surface plus a hairline border. No large shadow,
    // because on a dark ground a shadow is invisible and a border is not.
    cardTheme: CardThemeData(
      color: p.raised,
      elevation: 0,
      shadowColor: const Color(0x00000000),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.lg),
        side: BorderSide(color: p.border),
      ),
    ),

    // ── Buttons ────────────────────────────────────────────────────────
    // Rounded rectangles at 12px, not pills.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: isDark ? const Color(0xFF061018) : Colors.white,
        elevation: 0,
        minimumSize: const Size(64, ControlSize.md),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.sm + 2,
        ),
        textStyle: const TextStyle(
          fontSize: TypeScale.body,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.md),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: isDark ? const Color(0xFF061018) : Colors.white,
        minimumSize: const Size(64, ControlSize.md),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.sm + 2,
        ),
        textStyle: const TextStyle(
          fontSize: TypeScale.body,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.accent,
        backgroundColor: p.surface,
        minimumSize: const Size(64, ControlSize.md),
        side: BorderSide(color: p.border),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.sm + 2,
        ),
        textStyle: const TextStyle(
          fontSize: TypeScale.body,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.textSecondary,
        minimumSize: const Size.square(ControlSize.sm),
      ),
    ),

    // ── Inputs ─────────────────────────────────────────────────────────
    // A faint fill plus a border; on focus the border turns cyan and a soft
    // outer glow appears rather than a hard 2px outline.
    inputDecorationTheme: InputDecorationTheme(
      fillColor: p.fieldFill,
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.sm + 2,
        vertical: Insets.sm + 3,
      ),
      border: _inputBorder(p.border, 0),
      enabledBorder: _inputBorder(p.border, 0),
      focusedBorder: _inputBorder(p.accent, 0.8),
      errorBorder: _inputBorder(GossColors.error, 0),
      focusedErrorBorder: _inputBorder(GossColors.error, 0.8),
      hintStyle: TextStyle(color: p.textMuted, fontSize: TypeScale.body),
      labelStyle: TextStyle(
        color: p.textSecondary,
        fontSize: TypeScale.secondary,
      ),
      floatingLabelStyle: TextStyle(
        color: p.accent,
        fontSize: TypeScale.secondary,
      ),
      prefixIconColor: p.textMuted,
      suffixIconColor: p.textMuted,
    ),

    // ── Lists ──────────────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      minVerticalPadding: Insets.sm,
      horizontalTitleGap: Insets.sm,
      iconColor: p.textSecondary,
      textColor: p.text,
      titleTextStyle: TextStyle(
        fontSize: TypeScale.body,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: TypeScale.caption,
        color: p.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.md),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      side: BorderSide(color: p.border),
      labelStyle: TextStyle(
        fontSize: TypeScale.caption,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
      padding: const EdgeInsets.symmetric(horizontal: Insets.xs, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.sm),
      ),
    ),

    dataTableTheme: DataTableThemeData(
      headingTextStyle: TextStyle(
        color: p.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: TypeScale.caption,
        letterSpacing: 0.3,
      ),
      dataTextStyle: TextStyle(color: p.text, fontSize: TypeScale.body),
      headingRowColor: WidgetStatePropertyAll(p.surface),
      dividerThickness: 1,
    ),

    // ── Navigation ─────────────────────────────────────────────────────
    // The selected item is marked by a low-alpha cyan pill and a cyan glyph —
    // never by a large filled block.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 66,
      indicatorColor: p.accentTint,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.md),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: TypeScale.micro,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? p.accent : p.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: IconSize.nav,
          color: selected ? p.accent : p.textMuted,
          weight: selected ? 600 : 500,
        );
      }),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: isDark ? const Color(0xFF061018) : Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 2,
      highlightElevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.lg),
      ),
    ),

    // ── Feedback ───────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.raised,
      contentTextStyle: TextStyle(color: p.text, fontSize: TypeScale.body),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.all(Insets.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        side: BorderSide(color: p.border),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.sheet),
        side: BorderSide(color: p.border),
      ),
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: TypeScale.sectionTitle,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      contentTextStyle: TextStyle(
        color: p.textSecondary,
        fontSize: TypeScale.body,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: p.border,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Corners.sheet),
        ),
      ),
    ),

    drawerTheme: DrawerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      width: 300,
      // Directional shapes so the rounded edge lands on whichever side the
      // drawer slides in from, in both LTR and RTL.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(Corners.xl),
        ),
      ),
      endShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(Corners.xl),
        ),
      ),
    ),

    // ── Progress and switches ──────────────────────────────────────────
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearMinHeight: 4,
      linearTrackColor: p.border,
      circularTrackColor: p.border,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return isDark ? const Color(0xFF061018) : Colors.white;
        }
        return p.textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return p.accent;
        return p.fieldFill;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return p.accent;
        return p.border;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return p.accent;
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(
        isDark ? const Color(0xFF061018) : Colors.white,
      ),
      side: BorderSide(color: p.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return p.accent;
        return p.border;
      }),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.accent,
      unselectedLabelColor: p.textMuted,
      labelStyle: const TextStyle(
        fontSize: TypeScale.secondary,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: TypeScale.secondary,
        fontWeight: FontWeight.w500,
      ),
      // `label` size already draws a 2dp accent rule; the removed
      // `indicatorWeight` flag had no replacement that behaves better here.
      indicatorSize: TabBarIndicatorSize.label,
      indicatorColor: p.accent,
      dividerColor: p.border,
      labelPadding: const EdgeInsets.symmetric(horizontal: Insets.xs),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(Corners.sm),
        border: Border.all(color: p.border),
      ),
      textStyle: TextStyle(color: p.text, fontSize: TypeScale.caption),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xs,
        vertical: Insets.xs - 2,
      ),
      waitDuration: const Duration(milliseconds: 500),
    ),
    splashFactory: InkRipple.splashFactory,
  );
}

/// A 1px input border.
///
/// The focused state is expressed as a slightly brighter accent border rather
/// than a thicker outline; `BorderSide.shadows` was removed from the SDK, so
/// the soft glow is left to the accent colour itself.
OutlineInputBorder _inputBorder(Color color, double emphasis) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(Corners.md),
      borderSide: BorderSide(color: color, width: 1 + emphasis),
    );

ThemeData gossDarkTheme({bool isArabic = false}) =>
    gossTheme(isArabic: isArabic, dark: true);

/// Convenience accessors so widgets can read the resolved token set without
/// recomputing a palette.
extension GossModeColors on BuildContext {
  ThemeData get _theme => Theme.of(this);

  bool get isDarkMode => _theme.brightness == Brightness.dark;

  Color get accentColor => isDarkMode ? GossColors.cyan : GossColors.cyanDeep;

  Color get brandColor =>
      isDarkMode ? GossColors.burgundyBright : GossColors.burgundy;

  Color get dangerColor => GossColors.error;

  Color get surfaceColor =>
      isDarkMode ? GossColors.darkSurface : GossColors.lightSurface;

  Color get raisedColor =>
      isDarkMode ? GossColors.darkElevated : GossColors.lightSurface;

  Color get borderColor =>
      isDarkMode ? GossColors.darkBorder : GossColors.lightBorder;

  Color get fieldFillColor =>
      isDarkMode ? GossColors.darkBgAlt : GossColors.lightSurfaceAlt;

  /// Aliases kept for the many screens that still call the older names.
  Color get cardColor => raisedColor;
  Color get sectionColor => surfaceColor;
  Color get altSectionColor =>
      isDarkMode ? GossColors.darkBg : GossColors.lightBg;

  Color get headingColor =>
      isDarkMode ? GossColors.darkText : GossColors.lightText;

  Color get bodyColor =>
      isDarkMode ? GossColors.darkText : GossColors.lightText;

  Color get secondaryTextColor =>
      isDarkMode ? GossColors.darkTextSecondary : GossColors.lightTextSecondary;

  Color get mutedColor =>
      isDarkMode ? GossColors.darkTextMuted : GossColors.lightTextMuted;

  Color get successColor => GossColors.success;
  Color get warningColor => GossColors.warning;
}
