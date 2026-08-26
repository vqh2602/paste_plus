import 'package:clipflow/core/utils/color_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts a color into the supported clipboard formats', () {
    expect(ColorParser.convert('#ea3380', ClipboardColorFormat.hex), '#EA3380');
    expect(
      ColorParser.convert('#ea3380', ClipboardColorFormat.rgb),
      'rgb(234, 51, 128)',
    );
    expect(
      ColorParser.convert('#ea3380', ClipboardColorFormat.hsl),
      'hsl(335°, 81%, 56%)',
    );
    expect(
      ColorParser.convert('#ea3380', ClipboardColorFormat.hsv),
      'hsv(335°, 78%, 92%)',
    );
    expect(
      ColorParser.convert('#ea3380', ClipboardColorFormat.cmyk),
      'cmyk(0%, 78%, 45%, 8%)',
    );
  });

  test('converted colors can be parsed again and have a nearest name', () {
    final source = ColorParser.parse('#ea3380')!;
    expect(ColorParser.nearestName(source), 'Violet Red');

    for (final format in ClipboardColorFormat.values) {
      final converted = ColorParser.formatColor(source, format);
      expect(ColorParser.parse(converted), isNotNull, reason: converted);
    }
  });
}
