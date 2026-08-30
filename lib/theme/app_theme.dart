import 'package:flutter/material.dart';

/// App-wide colour palette (spec sec. 14: "clear status colours, avoid
/// clutter"). Every accent here is picked to stay readable as a text /
/// icon colour on a light surface *and* as a 10-15% tint behind them,
/// which is how they get used: [AppColors.tintedBox] pairs a solid
/// foreground with a washed-out background of the same hue.
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFF2563EB); // primary seed
  static const Color indigo = Color(0xFF4F46E5);
  static const Color violet = Color(0xFF7C3AED);
  static const Color teal = Color(0xFF0D9488);
  static const Color green = Color(0xFF16A34A);
  static const Color amber = Color(0xFFD97706);
  static const Color orange = Color(0xFFEA580C);
  static const Color rose = Color(0xFFE11D48);
  static const Color cyan = Color(0xFF0891B2);
  static const Color pink = Color(0xFFDB2777);
  static const Color slate = Color(0xFF475569);

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
      if (label == entry.key || label.startsWith('${entry.key} ')) return entry.value;
    }
    return brand;
  }

  /// Standard "icon or text on a tint of its own colour" decoration.
  static BoxDecoration tintedBox(Color color, {double radius = 12, bool border = true}) {
    return BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(radius),
      border: border ? Border.all(color: color.withOpacity(0.25)) : null,
    );
  }
}

/// Builds the single [ThemeData] used by MaterialApp in main.dart.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand);

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    dividerColor: scheme.outlineVariant,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    listTileTheme: ListTileThemeData(
      selectedColor: AppColors.brand,
      selectedTileColor: AppColors.brand.withOpacity(0.10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.brand, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: AppColors.slate,
      textColor: AppColors.slate,
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}
