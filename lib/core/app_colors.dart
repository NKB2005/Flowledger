import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.highlight,
  });

  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color highlight;
}

class AppColor {
  static final revision = ValueNotifier<int>(0);
  static const palettes = [
    AppPalette(
      id: 'mint',
      name: 'Mint',
      primary: Color(0xFF3BEBB0),
      secondary: Color(0xFF8C6BFF),
      highlight: Color(0xFFFF736B),
    ),
    AppPalette(
      id: 'ocean',
      name: 'Ocean',
      primary: Color(0xFF54C8E8),
      secondary: Color(0xFF6586E8),
      highlight: Color(0xFFF2A65A),
    ),
    AppPalette(
      id: 'berry',
      name: 'Berry',
      primary: Color(0xFFF47FA8),
      secondary: Color(0xFF57C7B4),
      highlight: Color(0xFFE8B65C),
    ),
  ];

  static Color bg = const Color(0xFF090E1C);
  static Color text = const Color(0xFFF0F7FF);
  static Color muted = const Color(0xFF9EB0CC);
  static Color surface = const Color(0x1AFFFFFF);
  static Color border = const Color(0x2EFFFFFF);
  static Color mint = palettes.first.primary;
  static Color violet = palettes.first.secondary;
  static Color coral = palettes.first.highlight;
  static bool isDarkMode = true;
  static String paletteId = 'mint';
  static double dockBlur = 18;
  static double dockOpacity = .24;
  static bool showAmbientBackground = true;
  static bool showDockLabels = true;

  static Color get dockSurface => Colors.white.withValues(
    alpha: isDarkMode ? .025 + dockOpacity * .24 : .12 + dockOpacity * .52,
  );

  static Color get card => isDarkMode ? const Color(0xFF151F30) : Colors.white;
  static Color get glassSurface => surface;

  static Future<void> loadAppearance() async {
    final preferences = await SharedPreferences.getInstance();
    isDarkMode = preferences.getBool('appearance_dark_mode') ?? true;
    paletteId = preferences.getString('appearance_palette') ?? 'mint';
    dockBlur = (preferences.getDouble('appearance_dock_blur') ?? 18)
        .clamp(0, 28)
        .toDouble();
    dockOpacity = (preferences.getDouble('appearance_dock_opacity') ?? .24)
        .clamp(0, 1)
        .toDouble();
    showAmbientBackground =
        preferences.getBool('appearance_ambient_background') ?? true;
    showDockLabels = preferences.getBool('appearance_dock_labels') ?? true;
    setDarkMode(isDarkMode, notify: false);
    setPalette(paletteId, notify: false);
    revision.value++;
  }

  static Future<void> saveAppearance() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('appearance_dark_mode', isDarkMode);
    await preferences.setString('appearance_palette', paletteId);
    await preferences.setDouble('appearance_dock_blur', dockBlur);
    await preferences.setDouble('appearance_dock_opacity', dockOpacity);
    await preferences.setBool(
      'appearance_ambient_background',
      showAmbientBackground,
    );
    await preferences.setBool('appearance_dock_labels', showDockLabels);
  }

  static void setDarkMode(bool isDark, {bool notify = true}) {
    isDarkMode = isDark;
    bg = isDark ? const Color(0xFF090E1C) : const Color(0xFFF0F3F8);
    text = isDark ? const Color(0xFFF0F7FF) : const Color(0xFF172033);
    muted = isDark ? const Color(0xFF9EB0CC) : const Color(0xFF5C6A80);
    surface = isDark ? const Color(0x1AFFFFFF) : const Color(0xCCFFFFFF);
    border = isDark ? const Color(0x2EFFFFFF) : const Color(0x205C6A80);
    if (notify) revision.value++;
  }

  static void setPalette(String id, {bool notify = true}) {
    final palette = palettes.firstWhere(
      (item) => item.id == id,
      orElse: () => palettes.first,
    );
    paletteId = palette.id;
    mint = palette.primary;
    violet = palette.secondary;
    coral = palette.highlight;
    if (notify) revision.value++;
  }
}
