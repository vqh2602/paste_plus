import 'package:flutter/cupertino.dart';

class AppTheme {
  const AppTheme._();

  static const Map<String, Color> accentColors = {
    // Standard macOS Modern
    'indigo': Color(0xFF5E5CE6),
    'blue': Color(0xFF0A84FF),
    'mint': Color(0xFF30D158),
    'orange': Color(0xFFFF9F0A),
    'rose': Color(0xFFFF375F),
    'violet': Color(0xFFAF52DE),
    'slate': Color(0xFF8E8E93),

    // Light Theme Balanced Pastel Suite (Soft, Elegant, High Legibility)
    'pastel_lavender': Color(0xFF7C67EE),
    'pastel_periwinkle': Color(0xFF6C8EEF),
    'pastel_sky': Color(0xFF4B9EF6),
    'pastel_cyan': Color(0xFF29B6F6),
    'pastel_mint': Color(0xFF26C6DA),
    'pastel_sage': Color(0xFF4DB6AC),
    'pastel_emerald': Color(0xFF4CAF50),
    'pastel_lime': Color(0xFF8BC34A),
    'pastel_butter': Color(0xFFF5A623),
    'pastel_apricot': Color(0xFFFB8C00),
    'pastel_peach': Color(0xFFFF7043),
    'pastel_coral': Color(0xFFFF5252),
    'pastel_rose': Color(0xFFEC407A),
    'pastel_sakura': Color(0xFFF06292),
    'pastel_lilac': Color(0xFFAB47BC),
    'pastel_plum': Color(0xFF8E24AA),
    'pastel_mocha': Color(0xFFA1785C),
    'pastel_slate': Color(0xFF78909C),
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
