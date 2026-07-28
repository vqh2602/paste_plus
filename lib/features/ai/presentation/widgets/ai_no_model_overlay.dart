import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/ai_model_info.dart';
import '../../services/ai_model_downloader_service.dart';

/// Overlay that blocks AI Chat usage until at least one model is downloaded.
/// Used by both AiChatScreen and AiChatDialog.
class AiNoModelOverlay extends ConsumerWidget {
  const AiNoModelOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiState = ref.watch(aiControllerProvider);
    final aiNotifier = ref.read(aiControllerProvider.notifier);

    // Show top 3 lightest models as recommendations
    final recommendedModels = AiModelInfo.thinkingModels.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Icon
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: CupertinoColors.systemOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.cloud_download,
              size: 44,
              color: CupertinoColors.systemOrange,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'ai_no_model_title'.tr,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            'ai_no_model_desc'.tr,
            style: TextStyle(
              fontSize: 14,
              color: resolveColor(context, ClipFlowColors.secondaryText),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Recommendation Label
          Row(
            children: [
              const Icon(
                CupertinoIcons.star_fill,
                size: 14,
                color: CupertinoColors.systemOrange,
              ),
              const SizedBox(width: 6),
              Text(
                'ai_recommend_model'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Model Cards
          ...recommendedModels.map((model) {
            final downloadState = aiState.downloadStates[model.id] ??
                DownloadState.notDownloaded;
            final progress = aiState.downloadProgresses[model.id];
            final isFirst = model == recommendedModels.first;

            return _ModelCard(
              model: model,
              downloadState: downloadState,
              progress: progress,
              isRecommended: isFirst,
              onDownload: () => aiNotifier.startDownload(model),
              onResume: () => aiNotifier.resumeDownload(model),
              onCancel: () => aiNotifier.cancelDownload(model.id),
              onDeletePartial: () =>
                  aiNotifier.deleteModel(model.id),
            );
          }),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.downloadState,
    required this.progress,
    required this.isRecommended,
    required this.onDownload,
    required this.onResume,
    required this.onCancel,
    required this.onDeletePartial,
  });

  final AiModelInfo model;
  final DownloadState downloadState;
  final ModelDownloadProgress? progress;
  final bool isRecommended;
  final VoidCallback onDownload;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onDeletePartial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CupertinoSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              model.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeOrange
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ai_recommend_model'.tr,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.activeOrange,
                                ),
                              ),
                            ),
                          ],
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
                  '${model.fileSizeFormatted} • ${model.parameterSize}',
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
                _buildActionButton(context),
              ],
            ),

            // Download progress bar
            if (downloadState == DownloadState.downloading &&
                progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress!.progress,
                  backgroundColor:
                      resolveColor(context, ClipFlowColors.border),
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
                    '${progress!.bytesFormatted} (${progress!.percentage}%)',
                    style: TextStyle(
                      fontSize: 11,
                      color: resolveColor(
                        context,
                        ClipFlowColors.secondaryText,
                      ),
                    ),
                  ),
                  Text(
                    progress!.speedFormatted,
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
  }

  Widget _buildActionButton(BuildContext context) {
    switch (downloadState) {
      case DownloadState.downloaded:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: CupertinoColors.activeGreen.withValues(alpha: 0.15),
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
        );

      case DownloadState.downloading:
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          onPressed: onCancel,
          child: const Text(
            'Hủy tải',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.systemOrange,
            ),
          ),
        );

      case DownloadState.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onDeletePartial,
              child: Text(
                'ai_delete_partial'.tr,
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
              onPressed: onResume,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.play_fill, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'ai_resume_download'.tr,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );

      case DownloadState.error:
      case DownloadState.notDownloaded:
        return CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          borderRadius: BorderRadius.circular(8),
          onPressed: onDownload,
          child: Text(
            'ai_download_model'.tr,
            style: const TextStyle(fontSize: 12),
          ),
        );
    }
  }
}
