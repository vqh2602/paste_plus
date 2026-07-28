import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../ai/domain/ai_model_info.dart';
import '../../../ai/services/ai_model_downloader_service.dart';
import 'settings_helpers.dart';

class AiSettingsSection extends ConsumerWidget {
  const AiSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final aiState = ref.watch(aiControllerProvider);
    final aiNotifier = ref.read(aiControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Privacy Callout Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.shield_fill,
                size: 22,
                color: CupertinoTheme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '100% Riêng tư & Ngoại tuyến (Offline)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ai_privacy_notice'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: resolveColor(context, ClipFlowColors.secondaryText),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Toggle Switch for AI Feature
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: 'ai_enabled'.tr,
              subtitle: 'ai_enabled_sub'.tr,
              value: settings.aiEnabled,
              onChanged: (value) {
                updateSettings(
                  ref,
                  (current) => current.copyWith(aiEnabled: value),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Thinking AI Models List Section
        CupertinoSectionLabel('ai_model_selection'.tr),
        Text(
          'ai_model_selection_sub'.tr,
          style: TextStyle(
            fontSize: 12,
            color: resolveColor(context, ClipFlowColors.secondaryText),
          ),
        ),
        const SizedBox(height: 12),

        ...AiModelInfo.thinkingModels.map((model) {
          final isSelected = aiState.selectedModelId == model.id;
          final downloadState =
              aiState.downloadStates[model.id] ?? DownloadState.notDownloaded;
          final progress = aiState.downloadProgresses[model.id];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CupertinoSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CupertinoPressable(
                        onPressed: () => aiNotifier.selectModel(model.id),
                        child: Icon(
                          isSelected
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.circle,
                          color: isSelected
                              ? CupertinoTheme.of(context).primaryColor
                              : resolveColor(context, ClipFlowColors.secondaryText),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    model.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemPurple
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Thinking Model',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.systemPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              model.description,
                              style: TextStyle(
                                fontSize: 12,
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Kích thước: ${model.fileSizeFormatted} • ${model.parameterSize}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: resolveColor(
                            context,
                            ClipFlowColors.secondaryText,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Download / Delete Status Buttons
                      if (downloadState == DownloadState.downloaded) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeGreen
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.checkmark_alt_circle_fill,
                                size: 12,
                                color: CupertinoColors.activeGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ai_downloaded'.tr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.activeGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onPressed: () => aiNotifier.deleteModel(model.id),
                          child: Text(
                            'ai_delete_model'.tr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                        ),
                      ] else if (downloadState == DownloadState.downloading) ...[
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onPressed: () => aiNotifier.cancelDownload(model.id),
                          child: const Text(
                            'Hủy tải',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemOrange,
                            ),
                          ),
                        ),
                      ] else ...[
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          onPressed: () => aiNotifier.startDownload(model),
                          child: Text(
                            'ai_download_model'.tr,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Download Progress Bar
                  if (downloadState == DownloadState.downloading && progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.progress,
                        backgroundColor: resolveColor(context, ClipFlowColors.border),
                        valueColor: AlwaysStoppedAnimation(
                          CupertinoTheme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${progress.bytesFormatted} (${progress.percentage}%)',
                          style: TextStyle(
                            fontSize: 11,
                            color: resolveColor(context, ClipFlowColors.secondaryText),
                          ),
                        ),
                        Text(
                          progress.speedFormatted,
                          style: TextStyle(
                            fontSize: 11,
                            color: resolveColor(context, ClipFlowColors.secondaryText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
