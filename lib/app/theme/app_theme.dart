import 'package:flutter/cupertino.dart';

class AppTheme {
  const AppTheme._();

  static const primary = Color(0xFF5E5CE6);

  static CupertinoThemeData theme(String mode) {
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
      textTheme: const CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: '.SF Pro Text',
          fontSize: 15,
          color: CupertinoColors.label,
        ),
        actionTextStyle: TextStyle(fontFamily: '.SF Pro Text', color: primary),
        navTitleTextStyle: TextStyle(
          fontFamily: '.SF Pro Display',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label,
        ),
      ),
    );
  }
}
