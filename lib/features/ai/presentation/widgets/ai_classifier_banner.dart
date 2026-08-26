import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/localization_extensions.dart';
import '../../domain/ai_model_info.dart';
import '../../services/ai_model_downloader_service.dart';
import '../../services/ai_utility_classifier.dart';

/// A slim, non-blocking banner that appears when the Qwen 0.6B classifier
/// model has not been downloaded yet.
///
/// This does NOT block AI usage — the user can still chat with their selected
/// answer model. The banner simply informs them that routing accuracy is
/// reduced and offers a one-tap download.
class AiClassifierBanner extends ConsumerWidget {
  const AiClassifierBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiState = ref.watch(aiControllerProvider);

    // Only show when the classifier model is genuinely missing.
    if (!aiState.isClassifierModelMissing) return const SizedBox.shrink();

    final classifierId = AiUtilityClassifier.utilityModelId;
    final classifierModel = AiModelInfo.findById(classifierId);
    final downloadState =
        aiState.downloadStates[classifierId] ?? DownloadState.notDownloaded;
    final progress = aiState.downloadProgresses[classifierId];
    final isDownloading = downloadState == DownloadState.downloading;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: CupertinoColors.systemOrange.withValues(alpha: 0.10),
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.systemOrange.withValues(alpha: 0.25),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.sparkles,
                  size: 14,
                  color: CupertinoColors.systemOrange,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    context.l10n.ai_classifier_banner_desc,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemOrange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isDownloading)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () =>
                        ref.read(aiControllerProvider.notifier).cancelDownload(
                          classifierId,
                        ),
                    child: Text(
                      context.l10n.cancel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.systemOrange,
                      ),
                    ),
                  )
                else
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    color: CupertinoColors.systemOrange,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => ref
                        .read(aiControllerProvider.notifier)
                        .downloadClassifierModel(),
                    child: Text(
                      '${context.l10n.download}  •  ${classifierModel.fileSizeFormatted}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
              ],
            ),

            // Inline progress bar while downloading
            if (isDownloading && progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.progress,
                  minHeight: 3,
                  backgroundColor:
                      CupertinoColors.systemOrange.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(
                    CupertinoColors.systemOrange,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.bytesFormatted}  •  ${progress.speedFormatted}',
                style: TextStyle(
                  fontSize: 10,
                  color: CupertinoColors.systemOrange.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
