import 'package:flutter/material.dart';

/// App-wide colour palette (spec sec. 14: "clear status colours, avoid
/// clutter"). Every accent here is picked to stay readable as a text /
/// icon colour on a light surface *and* as a 10-15% tint behind them,
/// which is how they get used: [AppColors.tintedBox] pairs a solid
/// foreground with a washed-out background of the same hue.
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFF1D4ED8);
  static const Color indigo = Color(0xFF4338CA);
  static const Color violet = Color(0xFF6D28D9);
  static const Color teal = Color(0xFF0F766E);
  static const Color green = Color(0xFF15803D);
  static const Color amber = Color(0xFFB45309);
  static const Color orange = Color(0xFFC2410C);
  static const Color rose = Color(0xFFBE123C);
  static const Color cyan = Color(0xFF0E7490);
  static const Color pink = Color(0xFFBE185D);
  static const Color slate = Color(0xFF475569);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color page = Color(0xFFF6F8FB);
  static const Color line = Color(0xFFE2E8F0);

  /// Rotated through wherever a list of tiles needs distinct accents
  /// (dashboard KPIs) -- ordered so neighbours never share a hue family.
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
  /// back to the brand blue so a new module still looks intentional.
  static const Map<String, Color> _byModule = {
    'Dashboard': indigo,
    'Companies': brand,
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
      {double radius = 12, bool border = true}) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(radius),
      border: border ? Border.all(color: color.withValues(alpha: 0.25)) : null,
    );
  }
}

/// Builds the single [ThemeData] used by MaterialApp in main.dart.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.light,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.page,
    dividerColor: AppColors.line,
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    listTileTheme: ListTileThemeData(
      selectedColor: AppColors.brand,
      selectedTileColor: AppColors.brand.withValues(alpha: 0.08),
      iconColor: AppColors.muted,
      textColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.brand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.rose),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      titleTextStyle: const TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: AppColors.slate,
      textColor: AppColors.slate,
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}
