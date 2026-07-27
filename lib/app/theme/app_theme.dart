import 'package:flutter/cupertino.dart';

class AppTheme {
  const AppTheme._();

  static const Map<String, Color> accentColors = {
    // Standard & Vivid
    'indigo': Color(0xFF5E5CE6),
    'blue': Color(0xFF0A84FF),
    'mint': Color(0xFF30D158),
    'orange': Color(0xFFFF9F0A),
    'rose': Color(0xFFFF375F),
    'violet': Color(0xFFAF52DE),
    'slate': Color(0xFF8E8E93),

    // Pastel Collection
    'pastel_lavender': Color(0xFFA29BFE),
    'pastel_sky': Color(0xFF74B9FF),
    'pastel_mint': Color(0xFF81ECEC),
    'pastel_matcha': Color(0xFFA8E6CF),
    'pastel_butter': Color(0xFFFDCB6E),
    'pastel_peach': Color(0xFFFFB8B8),
    'pastel_coral': Color(0xFFFAB1A0),
    'pastel_rose': Color(0xFFFD79A8),
    'pastel_lilac': Color(0xFFE0BBE4),
  };

  static Color getAccent(String key) =>
      accentColors[key] ?? const Color(0xFF5E5CE6);

  static CupertinoThemeData theme(String mode, {String accentKey = 'indigo'}) {
    final primary = getAccent(accentKey);
    final brightness = switch (mode) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => null,
    };
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: primary,
      primaryContrastingColor: CupertinoColors.white,
      scaffoldBackgroundColor: const CupertinoDynamicColor.withBrightness(
        color: Color(0xFFF2F2F7),
        darkColor: Color(0xFF101116),
      ),
      barBackgroundColor: const CupertinoDynamicColor.withBrightness(
        color: Color(0xF7F7F7F7),
        darkColor: Color(0xF7202127),
      ),
      textTheme: CupertinoTextThemeData(
        textStyle: const TextStyle(
          fontFamily: '.SF Pro Text',
          fontSize: 15,
          color: CupertinoColors.label,
        ),
        actionTextStyle: TextStyle(fontFamily: '.SF Pro Text', color: primary),
        navTitleTextStyle: const TextStyle(
          fontFamily: '.SF Pro Display',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label,
        ),
      ),
    );
  }
}
