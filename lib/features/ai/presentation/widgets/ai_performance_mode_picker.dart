import 'package:flutter/cupertino.dart';

import '../../../../core/localization/localization_extensions.dart';
import '../../domain/ai_performance_mode.dart';

class AiPerformanceModePicker extends StatelessWidget {
  const AiPerformanceModePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AiPerformanceMode value;
  final ValueChanged<AiPerformanceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      key: const Key('ai-performance-mode'),
      minimumSize: const Size(36, 36),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onPressed: () => showCupertinoModalPopup<void>(
        context: context,
        builder: (popupContext) => CupertinoActionSheet(
          title: Text(context.l10n.ai_performance_mode),
          actions: AiPerformanceMode.values
              .map((mode) {
                return CupertinoActionSheetAction(
                  isDefaultAction: mode == value,
                  onPressed: () {
                    Navigator.pop(popupContext);
                    onChanged(mode);
                  },
                  child: Text(_label(context, mode)),
                );
              })
              .toList(growable: false),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(popupContext),
            child: Text(context.l10n.cancel),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(value), size: 16),
          const SizedBox(width: 4),
          Text(_label(context, value), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _label(BuildContext context, AiPerformanceMode mode) => switch (mode) {
    AiPerformanceMode.fast => context.l10n.ai_performance_fast,
    AiPerformanceMode.balanced => context.l10n.ai_performance_balanced,
    AiPerformanceMode.smart => context.l10n.ai_performance_smart,
  };

  IconData _icon(AiPerformanceMode mode) => switch (mode) {
    AiPerformanceMode.fast => CupertinoIcons.bolt_fill,
    AiPerformanceMode.balanced => CupertinoIcons.gauge,
    AiPerformanceMode.smart => CupertinoIcons.sparkles,
  };
}
