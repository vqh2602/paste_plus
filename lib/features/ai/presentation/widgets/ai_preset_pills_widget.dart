import 'package:flutter/cupertino.dart';

import '../../../../core/ui/cupertino_components.dart';
import '../../domain/ai_feature_action.dart';

class AiPresetPillsWidget extends StatelessWidget {
  const AiPresetPillsWidget({
    super.key,
    required this.onSelectGroup,
  });

  final ValueChanged<AiFeatureGroup> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: AiFeatureGroup.values.map((group) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: CupertinoPressable(
              onPressed: () => onSelectGroup(group),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: resolveColor(context, ClipFlowColors.surface),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: resolveColor(context, ClipFlowColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      group.icon,
                      size: 13,
                      color: CupertinoTheme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      group.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 10,
                      color: resolveColor(context, ClipFlowColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
