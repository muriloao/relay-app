import 'package:material_ui/material_ui.dart';

abstract final class RelayPalette {
  static const background = Color(0xFF202327);
  static const surface = Color(0xFF292D31);
  static const elevatedSurface = Color(0xFF34393E);
  static const primary = Color(0xFF9AD6B3);
  static const foreground = Color(0xFFF0F1F2);
  static const mutedForeground = Color(0xFF9DA2A7);
  static const border = Color(0xFF484D52);
  static const warning = Color(0xFFE1BE77);
  static const error = Color(0xFFE58D87);
}

final relayDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: RelayPalette.background,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: RelayPalette.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: RelayPalette.primary,
        onPrimary: const Color(0xFF17241C),
        surface: RelayPalette.surface,
        onSurface: RelayPalette.foreground,
        outline: RelayPalette.border,
        error: RelayPalette.error,
      ),
  appBarTheme: const AppBarTheme(
    backgroundColor: RelayPalette.background,
    foregroundColor: RelayPalette.foreground,
    centerTitle: false,
  ),
  dividerColor: RelayPalette.border,
);
