import 'package:material_ui/material_ui.dart';

abstract final class DreamForceTheme {
  static ThemeData light() => _theme(
    Brightness.light,
    const Color(0xFF256D5B),
    const Color(0xFFF6F8F5),
  );
  static ThemeData dark() =>
      _theme(Brightness.dark, const Color(0xFF77C6A7), const Color(0xFF101915));

  static ThemeData _theme(Brightness brightness, Color seed, Color background) {
    final colors = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
    );
  }
}
