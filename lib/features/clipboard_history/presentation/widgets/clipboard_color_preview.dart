import 'package:flutter/cupertino.dart';

import '../../../../core/ui/cupertino_components.dart';
import '../../../../core/utils/color_parser.dart';

class ClipboardColorPreview extends StatelessWidget {
  const ClipboardColorPreview({
    super.key,
    required this.value,
    required this.color,
    this.compact = false,
  });

  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final canonicalHex = ColorParser.formatColor(
      color,
      ClipboardColorFormat.hex,
    );
    final colorName = ColorParser.nearestName(color);

    if (compact) {
      return Container(
        key: const Key('clipboard-color-preview-compact'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: resolveColor(context, ClipFlowColors.sidebar),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: resolveColor(context, ClipFlowColors.border),
          ),
        ),
        child: Row(
          children: [
            _ColorSwatch(color: color, size: 72, ringWidth: 5),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    canonicalHex,
                    key: const Key('clipboard-color-value'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    colorName,
                    key: const Key('clipboard-color-name'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: resolveColor(
                        context,
                        ClipFlowColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('clipboard-color-preview'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 330),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: resolveColor(context, ClipFlowColors.sidebar),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: resolveColor(context, ClipFlowColors.border)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ColorSwatch(color: color, size: 190, ringWidth: 10),
          const SizedBox(height: 28),
          Text(
            canonicalHex,
            key: const Key('clipboard-color-value'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            colorName,
            key: const Key('clipboard-color-name'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
          if (value.trim().toUpperCase() != canonicalHex) ...[
            const SizedBox(height: 8),
            Text(
              value.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: resolveColor(context, ClipFlowColors.secondaryText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.size,
    required this.ringWidth,
  });

  final Color color;
  final double size;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('clipboard-color-swatch'),
      width: size,
      height: size,
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: resolveColor(context, ClipFlowColors.elevatedSurface),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
