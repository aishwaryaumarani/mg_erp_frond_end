import 'package:flutter/material.dart';

/// App-wide colour palette (spec sec. 14: "clear status colours, avoid
/// clutter").
///
/// The scheme is a classic corporate one -- a deep navy carries the brand,
/// an antique gold is the single decorative accent, and everything sits on
/// a warm off-white page rather than a cold grey. Status hues are
/// deliberately desaturated: each one stays readable as a text / icon
/// colour on a light surface *and* as a 10-15% tint behind them, which is
/// how they get used ([AppColors.tintedBox] pairs a solid foreground with a
/// washed-out background of the same hue).
class AppColors {
  AppColors._();

  // --- Brand -------------------------------------------------------
  /// Primary navy. Buttons, links, focus rings, selected states.
  static const Color brand = Color(0xFF1A3A63);

  /// Sidebar body -- the darkest navy, used as a solid nav ground.
  static const Color brandDark = Color(0xFF102844);

  /// Foot of the sidebar gradient; also the hover ground for nav rows.
  static const Color brandDarker = Color(0xFF0A1B30);

  /// Very light navy wash, for selected rows and quiet banners.
  static const Color brandWash = Color(0xFFEDF2F8);

  /// The one decorative accent: an antique gold. Reserved for the active
  /// nav marker, hero rules and brand flourishes -- never for status.
  static const Color gold = Color(0xFFB08833);
  static const Color goldLight = Color(0xFFDCBC6E);

  // --- Neutrals ----------------------------------------------------
  static const Color ink = Color(0xFF141C29);
  static const Color slate = Color(0xFF48525F);
  static const Color muted = Color(0xFF79828F);
  static const Color faint = Color(0xFFA3AAB4);
  static const Color surface = Color(0xFFFFFFFF);

  /// Table headers, toolbars and other "quiet shelf" surfaces.
  static const Color surfaceAlt = Color(0xFFF8F8F5);
  static const Color page = Color(0xFFF4F4F1);
  static const Color line = Color(0xFFE3E1DA);
  static const Color lineSoft = Color(0xFFEFEDE7);

  // --- Sidebar (on the dark navy ground) ---------------------------
  static const Color navText = Color(0xFFE7EBF1);
  static const Color navMuted = Color(0xFF8FA0B6);
  static const Color navLine = Color(0xFF1D3A5C);

  // --- Status / module hues ----------------------------------------
  static const Color indigo = Color(0xFF2E3F7F);
  static const Color violet = Color(0xFF4C3B87);
  static const Color teal = Color(0xFF15655F);
  static const Color green = Color(0xFF1E6B45);
  static const Color amber = Color(0xFF96690F);
  static const Color orange = Color(0xFFA35420);
  static const Color rose = Color(0xFF9E2B32);
  static const Color cyan = Color(0xFF15637A);
  static const Color pink = Color(0xFF8D3159);

  /// Rotated through wherever a list of tiles needs distinct accents --
  /// ordered so neighbours never share a hue family. Every entry is at a
  /// similar depth, so a row of them reads as one family rather than as a
  /// rainbow.
  static const List<Color> accents = [
    brand,
    green,
    orange,
    violet,
    teal,
    rose,
    cyan,
    amber,
    indigo,
    pink,
  ];

  static Color accentAt(int i) => accents[i % accents.length];

  /// One colour per top-level nav group / dashboard section, keyed by
  /// the label used in main.dart's NavGroup list. Unknown labels fall
  /// back to the brand navy so a new module still looks intentional.
  static const Map<String, Color> _byModule = {
    'Dashboard': brand,
    'Companies': indigo,
    'Masters': violet,
    'Sales': green,
    'Purchase': orange,
    'Inventory': teal,
    'Tasks': amber,
    'Accounts': rose,
    'Reports': cyan,
    'Settings': slate,
    'Team': pink,
  };

  /// Matches on the leading word so section titles like
  /// "Sales (Phase 2/3)" resolve to the same colour as the "Sales" nav
  /// group.
  static Color forModule(String label) {
    for (final entry in _byModule.entries) {
      if (label == entry.key || label.startsWith('${entry.key} ')) {
        return entry.value;
      }
    }
    return brand;
  }

  /// Standard "icon or text on a tint of its own colour" decoration.
  static BoxDecoration tintedBox(Color color,
      {double radius = 10, bool border = true}) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(radius),
      border: border ? Border.all(color: color.withValues(alpha: 0.22)) : null,
    );
  }

  /// Hairline-bordered white panel -- the shape every card, tile and
  /// toolbar in the app shares.
  static BoxDecoration panel({
    double radius = AppRadius.card,
    Color? color,
    Color? borderColor,
    bool shadow = false,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? line),
      boxShadow: shadow ? AppShadows.card : null,
    );
  }
}

/// Corner radii, named so the whole app rounds by the same amounts.
class AppRadius {
  AppRadius._();

  static const double chip = 6;
  static const double field = 8;
  static const double card = 10;
  static const double panel = 14;
  static const double pill = 999;
}

/// Shadows are used sparingly -- a classic layout leans on hairlines and
/// whitespace, so these stay barely-there and only lift interactive
/// surfaces off the page.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> get raised => [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.07),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}

/// Typography helpers.
///
/// The interface runs on the platform sans, which is what dense tabular
/// ERP data wants. The classic note comes from a serif reserved for brand
/// marks and page headings -- [AppText.serif].
///
/// That serif is Source Serif 4, bundled in assets/fonts and declared in
/// pubspec.yaml. It has to be bundled rather than named as a system face:
/// Flutter Web draws through CanvasKit, which cannot reach the host's
/// installed fonts, so a 'Georgia, serif' fallback renders as the default
/// sans on the web build and the distinction disappears exactly where
/// most people use the app.
class AppText {
  AppText._();

  static const String _serifFamily = 'SourceSerif';

  /// Only reached if the asset fails to load.
  static const List<String> _serifFallback = ['Georgia', 'serif'];

  /// A serif display style, for wordmarks and page/hero titles.
  static TextStyle serif({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.ink,
    double letterSpacing = -0.2,
    double? height,
  }) {
    return TextStyle(
      fontFamily: _serifFamily,
      fontFamilyFallback: _serifFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Small uppercase label above a value or section -- the classic
  /// "engraved caption" that keeps forms and detail views legible.
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.muted,
    letterSpacing: 0.8,
  );

  /// Figures that must line up column-to-column (money, quantities).
  static const TextStyle tabular = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
}

/// Builds the single [ThemeData] used by MaterialApp in main.dart.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.brand,
    onPrimary: Colors.white,
    secondary: AppColors.gold,
    onSecondary: Colors.white,
    error: AppColors.rose,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    outline: AppColors.line,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.page,
    dividerColor: AppColors.line,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    textTheme: _textTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.serif(fontSize: 19, fontWeight: FontWeight.w700),
      iconTheme: const IconThemeData(color: AppColors.slate, size: 21),
      shape: const Border(bottom: BorderSide(color: AppColors.line)),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      selectedColor: AppColors.brand,
      selectedTileColor: AppColors.brandWash,
      iconColor: AppColors.muted,
      textColor: AppColors.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.faint, fontSize: 14),
      labelStyle: const TextStyle(
        color: AppColors.muted,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.brand,
        fontWeight: FontWeight.w700,
      ),
      prefixIconColor: AppColors.faint,
      suffixIconColor: AppColors.faint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.rose),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.rose, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.38),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        backgroundColor: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        side: const BorderSide(color: AppColors.line),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 0.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.slate,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.muted,
        highlightColor: AppColors.brand.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(
        color: AppColors.slate,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
      headingRowHeight: 46,
      dataRowMinHeight: 46,
      dataRowMaxHeight: 58,
      dividerThickness: 1,
      horizontalMargin: 18,
      columnSpacing: 26,
      headingTextStyle: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: AppColors.slate,
        letterSpacing: 0.6,
      ),
      dataTextStyle: const TextStyle(fontSize: 13.5, color: AppColors.ink),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        side: const BorderSide(color: AppColors.line),
      ),
      titleTextStyle: AppText.serif(fontSize: 20),
      contentTextStyle: const TextStyle(
        color: AppColors.slate,
        fontSize: 14,
        height: 1.5,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.line),
      ),
      textStyle: const TextStyle(color: AppColors.ink, fontSize: 14),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      waitDuration: const Duration(milliseconds: 400),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.brandDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: AppColors.slate,
      textColor: AppColors.slate,
      shape: Border(),
      collapsedShape: Border(),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brand,
      linearMinHeight: 3,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: AppColors.faint, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Colors.white : AppColors.faint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.brand
            : AppColors.lineSoft,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.brand,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.brand,
      dividerColor: AppColors.line,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle:
          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor:
          WidgetStateProperty.all(AppColors.faint.withValues(alpha: 0.5)),
      radius: const Radius.circular(AppRadius.pill),
      thickness: WidgetStateProperty.all(8),
    ),
  );
}

/// Type scale. Headline-and-larger sizes carry the serif; everything from
/// title down stays in the sans so dense records and figures keep their
/// rhythm.
TextTheme _textTheme(TextTheme base) {
  return base.copyWith(
    displaySmall: AppText.serif(fontSize: 34, height: 1.2),
    headlineLarge: AppText.serif(fontSize: 30, height: 1.2),
    headlineMedium: AppText.serif(fontSize: 26, height: 1.25),
    headlineSmall: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.3,
      height: 1.25,
    ),
    titleLarge: AppText.serif(fontSize: 20, height: 1.3),
    titleMedium: const TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.1,
    ),
    titleSmall: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    bodyLarge: const TextStyle(
      fontSize: 15,
      color: AppColors.slate,
      height: 1.55,
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      color: AppColors.slate,
      height: 1.5,
    ),
    bodySmall: const TextStyle(
      fontSize: 12.5,
      color: AppColors.muted,
      height: 1.45,
    ),
    labelLarge: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: 0.2,
    ),
    labelMedium: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
    ),
    labelSmall: AppText.overline,
  );
}

/// A section heading: a short gold/module rule, the title, and an optional
/// trailing widget. Used at the top of dashboard blocks, form sections and
/// detail cards so every grouping is announced the same way.
class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? trailing;

  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.gold;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: subtitle == null ? 18 : 32,
          margin: const EdgeInsets.only(top: 2, right: 12),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.1,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
