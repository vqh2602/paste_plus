import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';

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
            color: CupertinoTheme.of(
              context,
            ).primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: CupertinoTheme.of(
                context,
              ).primaryColor.withValues(alpha: 0.25),
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
                    Text(
                      context.l10n.ai_privacy_title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.ai_privacy_notice,
                      style: TextStyle(
                        fontSize: 12,
                        color: resolveColor(
                          context,
                          ClipFlowColors.secondaryText,
                        ),
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
              title: context.l10n.ai_enabled,
              subtitle: context.l10n.ai_enabled_sub,
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
        CupertinoSectionLabel(context.l10n.ai_model_selection),
        Text(
          context.l10n.ai_model_selection_sub,
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
                              : resolveColor(
                                  context,
                                  ClipFlowColors.secondaryText,
                                ),
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (model.isThinkingModel) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.systemPurple
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          context.l10n.ai_badge_thinking,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: CupertinoColors.systemPurple,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    if (model.isMultimodal)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.activeBlue
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          context.l10n.ai_badge_vision,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: CupertinoColors.activeBlue,
                                          ),
                                        ),
                                      ),
                                  ],
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
                        '${context.l10n.ai_size_label}: ${model.fileSizeFormatted} • ${model.parameterSize}',
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
                            color: CupertinoColors.activeGreen.withValues(
                              alpha: 0.15,
                            ),
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
                                context.l10n.ai_downloaded,
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
                            context.l10n.ai_delete_model,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                        ),
                      ] else if (downloadState ==
                          DownloadState.downloading) ...[
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onPressed: () => aiNotifier.cancelDownload(model.id),
                          child: Text(
                            context.l10n.ai_cancel_download,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemOrange,
                            ),
                          ),
                        ),
                      ] else if (downloadState == DownloadState.paused) ...[
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () => aiNotifier.deleteModel(model.id),
                          child: Text(
                            context.l10n.ai_delete_partial,
                            style: const TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                        ),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          onPressed: () => aiNotifier.resumeDownload(model),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.play_fill, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.ai_resume_download,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
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
                            context.l10n.ai_download_model,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Download Progress Bar
                  if (downloadState == DownloadState.downloading &&
                      progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.progress,
                        backgroundColor: resolveColor(
                          context,
                          ClipFlowColors.border,
                        ),
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
                            color: resolveColor(
                              context,
                              ClipFlowColors.secondaryText,
                            ),
                          ),
                        ),
                        Text(
                          progress.speedFormatted,
                          style: TextStyle(
                            fontSize: 11,
                            color: resolveColor(
                              context,
                              ClipFlowColors.secondaryText,
                            ),
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
