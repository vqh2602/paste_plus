import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/ui/cupertino_components.dart';
import '../../domain/smart_text_tools.dart';

class CalculationResultLine extends StatelessWidget {
  const CalculationResultLine({
    super.key,
    required this.content,
    this.compact = false,
    this.enabled = true,
  });

  final String content;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final result = enabled ? SmartTextTools.calculate(content) : null;
    if (result == null) return const SizedBox.shrink();
    final accent = CupertinoTheme.of(context).primaryColor;
    return Container(
      key: const Key('calculation-result'),
      margin: EdgeInsets.only(top: compact ? 5 : 7),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.function, size: compact ? 12 : 13, color: accent),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${context.l10n.calculation_result}: $result',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: resolveColor(context, ClipFlowColors.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
