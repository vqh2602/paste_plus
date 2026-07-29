import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/painting.dart' show HSVColor;

class ColorParser {
  const ColorParser._();

  static Color? parse(String value) {
    value = value.trim();
    if (value.isEmpty) return null;

    // 1. HEX
    final hexMatch = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(value);
    if (hexMatch != null) {
      String hex = hexMatch.group(1)!;
      if (hex.length == 3) {
        hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
      } else if (hex.length == 4) {
        hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}';
      }
      
      if (hex.length == 6) {
        hex = 'FF$hex';
      } else if (hex.length == 8) {
        // CSS hex is RRGGBBAA, Flutter color is AARRGGBB
        hex = '${hex.substring(6, 8)}${hex.substring(0, 6)}';
      }
      
      final intValue = int.tryParse(hex, radix: 16);
      if (intValue != null) {
        return Color(intValue);
      }
    }

    // 2. RGB / RGBA
    final rgbMatch = RegExp(r'^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*([\d.]+))?\s*\)$', caseSensitive: false).firstMatch(value);
    if (rgbMatch != null) {
      final r = double.tryParse(rgbMatch.group(1)!) ?? 0;
      final g = double.tryParse(rgbMatch.group(2)!) ?? 0;
      final b = double.tryParse(rgbMatch.group(3)!) ?? 0;
      final aStr = rgbMatch.group(4);
      double a = 1.0;
      if (aStr != null) a = double.tryParse(aStr) ?? 1.0;
      return Color.fromARGB((a * 255).round().clamp(0, 255), r.round().clamp(0, 255), g.round().clamp(0, 255), b.round().clamp(0, 255));
    }

    // 3. HSL / HSLA
    final hslMatch = RegExp(r'^hsla?\(\s*([\d.]+)(?:deg|°)?\s*,\s*([\d.]+)%?\s*,\s*([\d.]+)%?(?:\s*,\s*([\d.]+))?\s*\)$', caseSensitive: false).firstMatch(value);
    if (hslMatch != null) {
      final h = double.tryParse(hslMatch.group(1)!) ?? 0;
      final s = (double.tryParse(hslMatch.group(2)!) ?? 0) / 100;
      final l = (double.tryParse(hslMatch.group(3)!) ?? 0) / 100;
      final aStr = hslMatch.group(4);
      double a = 1.0;
      if (aStr != null) a = double.tryParse(aStr) ?? 1.0;
      return _hslToColor(h, s, l, a);
    }

    // 4. HSV / HSB (e.g. 29°, 100%, 100% or hsv(29, 100%, 100%))
    final hsvMatch = RegExp(r'^(?:hsv|hsb)?\(?\s*([\d.]+)(?:deg|°)?\s*,\s*([\d.]+)%?\s*,\s*([\d.]+)%?(?:\s*,\s*([\d.]+))?\s*\)?$', caseSensitive: false).firstMatch(value);
    if (hsvMatch != null) {
      final h = double.tryParse(hsvMatch.group(1)!) ?? 0;
      final s = (double.tryParse(hsvMatch.group(2)!) ?? 0) / 100;
      final v = (double.tryParse(hsvMatch.group(3)!) ?? 0) / 100;
      final aStr = hsvMatch.group(4);
      double a = 1.0;
      if (aStr != null) a = double.tryParse(aStr) ?? 1.0;
      // Filter out raw numbers that accidentally match e.g. "10, 20, 30" might match, but usually they are hex if missing % and °
      // However regex enforces % on s and v.
      return HSVColor.fromAHSV(a, h.clamp(0.0, 360.0), s.clamp(0.0, 1.0), v.clamp(0.0, 1.0)).toColor();
    }

    // 5. CMYK (e.g. 0%, 52%, 100%, 0% or cmyk(0%, 52%, 100%, 0%))
    final cmykMatch = RegExp(r'^(?:cmyk)?\(?\s*([\d.]+)%?\s*,\s*([\d.]+)%?\s*,\s*([\d.]+)%?\s*,\s*([\d.]+)%?\s*\)?$', caseSensitive: false).firstMatch(value);
    if (cmykMatch != null) {
      final c = (double.tryParse(cmykMatch.group(1)!) ?? 0) / 100;
      final m = (double.tryParse(cmykMatch.group(2)!) ?? 0) / 100;
      final y = (double.tryParse(cmykMatch.group(3)!) ?? 0) / 100;
      final k = (double.tryParse(cmykMatch.group(4)!) ?? 0) / 100;
      
      final r = 255 * (1 - c) * (1 - k);
      final g = 255 * (1 - m) * (1 - k);
      final b = 255 * (1 - y) * (1 - k);
      return Color.fromARGB(255, r.round().clamp(0, 255), g.round().clamp(0, 255), b.round().clamp(0, 255));
    }

    // 6. LAB (L* 65, a* 45, b* 75 or lab(65, 45, 75))
    final labMatch = RegExp(r'^(?:lab)?\(?\s*L\*\s*([\d.]+)\s*,\s*a\*\s*(-?[\d.]+)\s*,\s*b\*\s*(-?[\d.]+)\s*\)?$', caseSensitive: false).firstMatch(value);
    if (labMatch != null) {
      final l = double.tryParse(labMatch.group(1)!) ?? 0;
      final a = double.tryParse(labMatch.group(2)!) ?? 0;
      final b = double.tryParse(labMatch.group(3)!) ?? 0;
      return _labToColor(l, a, b);
    }
    
    final labMatch2 = RegExp(r'^lab\(\s*([\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)$', caseSensitive: false).firstMatch(value);
    if (labMatch2 != null) {
      final l = double.tryParse(labMatch2.group(1)!) ?? 0;
      final a = double.tryParse(labMatch2.group(2)!) ?? 0;
      final b = double.tryParse(labMatch2.group(3)!) ?? 0;
      return _labToColor(l, a, b);
    }

    // 7. XYZ (X: 41, Y: 32, Z: 4 or xyz(41, 32, 4))
    final xyzMatch = RegExp(r'^(?:xyz)?\(?\s*X:\s*([\d.]+)\s*,\s*Y:\s*([\d.]+)\s*,\s*Z:\s*([\d.]+)\s*\)?$', caseSensitive: false).firstMatch(value);
    if (xyzMatch != null) {
      final x = double.tryParse(xyzMatch.group(1)!) ?? 0;
      final y = double.tryParse(xyzMatch.group(2)!) ?? 0;
      final z = double.tryParse(xyzMatch.group(3)!) ?? 0;
      return _xyzToColor(x, y, z);
    }
    
    final xyzMatch2 = RegExp(r'^xyz\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)$', caseSensitive: false).firstMatch(value);
    if (xyzMatch2 != null) {
      final x = double.tryParse(xyzMatch2.group(1)!) ?? 0;
      final y = double.tryParse(xyzMatch2.group(2)!) ?? 0;
      final z = double.tryParse(xyzMatch2.group(3)!) ?? 0;
      return _xyzToColor(x, y, z);
    }

    // 8. HWB (hwb(29, 10%, 20%))
    final hwbMatch = RegExp(r'^hwb\(\s*([\d.]+)(?:deg|°)?\s*,\s*([\d.]+)%?\s*,\s*([\d.]+)%?(?:\s*,\s*([\d.]+))?\s*\)$', caseSensitive: false).firstMatch(value);
    if (hwbMatch != null) {
      final h = double.tryParse(hwbMatch.group(1)!) ?? 0;
      final w = (double.tryParse(hwbMatch.group(2)!) ?? 0) / 100;
      final b = (double.tryParse(hwbMatch.group(3)!) ?? 0) / 100;
      final aStr = hwbMatch.group(4);
      double a = 1.0;
      if (aStr != null) a = double.tryParse(aStr) ?? 1.0;
      return _hwbToColor(h, w, b, a);
    }

    return null;
  }

  // --- Helpers for color conversion ---

  static Color _hslToColor(double h, double s, double l, double a) {
    h = h.clamp(0.0, 360.0) / 360.0;
    s = s.clamp(0.0, 1.0);
    l = l.clamp(0.0, 1.0);
    
    double r, g, b;
    if (s == 0) {
      r = g = b = l;
    } else {
      double hue2rgb(double p, double q, double t) {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1/6) return p + (q - p) * 6 * t;
        if (t < 1/2) return q;
        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
        return p;
      }
      final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final p = 2 * l - q;
      r = hue2rgb(p, q, h + 1/3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1/3);
    }
    return Color.fromARGB((a * 255).round().clamp(0, 255), (r * 255).round().clamp(0, 255), (g * 255).round().clamp(0, 255), (b * 255).round().clamp(0, 255));
  }
  
  static Color _hwbToColor(double h, double w, double b, double a) {
    if (w + b >= 1) {
      final gray = w / (w + b);
      return Color.fromARGB((a * 255).round().clamp(0, 255), (gray * 255).round(), (gray * 255).round(), (gray * 255).round());
    }
    // HWB to RGB can be done via HSL/HSV. In HSV, v = 1 - b, s = 1 - w / v
    final v = 1 - b;
    final s = v == 0 ? 0.0 : 1 - (w / v);
    return HSVColor.fromAHSV(a, h.clamp(0.0, 360.0), s.clamp(0.0, 1.0), v.clamp(0.0, 1.0)).toColor();
  }

  static Color _labToColor(double l, double a, double b) {
    // LAB to XYZ (D65)
    double y = (l + 16) / 116;
    double x = a / 500 + y;
    double z = y - b / 200;

    double x3 = x * x * x;
    double y3 = y * y * y;
    double z3 = z * z * z;

    x = ((x3 > 0.008856) ? x3 : (x - 16/116) / 7.787) * 95.047;
    y = ((y3 > 0.008856) ? y3 : (y - 16/116) / 7.787) * 100.000;
    z = ((z3 > 0.008856) ? z3 : (z - 16/116) / 7.787) * 108.883;

    return _xyzToColor(x, y, z);
  }

  static Color _xyzToColor(double x, double y, double z) {
    // Assuming x,y,z in 0..100
    x = x / 100;
    y = y / 100;
    z = z / 100;

    double r = x *  3.2406 + y * -1.5372 + z * -0.4986;
    double g = x * -0.9689 + y *  1.8758 + z *  0.0415;
    double b = x *  0.0557 + y * -0.2040 + z *  1.0570;

    r = r > 0.0031308 ? 1.055 * math.pow(r, 1/2.4) - 0.055 : 12.92 * r;
    g = g > 0.0031308 ? 1.055 * math.pow(g, 1/2.4) - 0.055 : 12.92 * g;
    b = b > 0.0031308 ? 1.055 * math.pow(b, 1/2.4) - 0.055 : 12.92 * b;

    return Color.fromARGB(255, (r * 255).round().clamp(0, 255), (g * 255).round().clamp(0, 255), (b * 255).round().clamp(0, 255));
  }
}
