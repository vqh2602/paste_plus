import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator, Tooltip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/providers.dart';
import '../../../../core/services/update_download_provider.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/ui/cupertino_components.dart';
import 'settings_helpers.dart';

class AboutSettingsSection extends ConsumerStatefulWidget {
  const AboutSettingsSection({super.key});

  @override
  ConsumerState<AboutSettingsSection> createState() =>
      _AboutSettingsSectionState();
}

class _AboutSettingsSectionState extends ConsumerState<AboutSettingsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateDownloadProvider.notifier).checkOnly();
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = ref.watch(updateDownloadProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSurface(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // App icon (tap 7× to toggle AI debug)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final changed = ref
                          .read(aiDebugControllerProvider.notifier)
                          .registerAppIconTap();
                      if (!changed) return;
                      final enabled = ref
                          .read(aiDebugControllerProvider)
                          .isEnabled;
                      showCupertinoNotice(
                        context,
                        enabled ? 'Đã bật AI Debug' : 'Đã tắt AI Debug',
                      );
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: const DecorationImage(
                          image: AssetImage(
                            'assets/branding/clipflow_app_icon.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // App name + version
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ClipFlow',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.version_label.replaceAll(
                            '@v',
                            UpdateService.currentVersion,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: resolveColor(
                              context,
                              ClipFlowColors.secondaryText,
                            ),
                          ),
                        ),
                        // Show available version if found
                        if (update.latestVersion != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Bản mới: ${update.latestVersion}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CupertinoTheme.of(context).primaryColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.about_tagline,
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

                  // Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: context.l10n.github_source,
                        child: CupertinoButton(
                          padding: const EdgeInsets.all(8),
                          onPressed: () => ref
                              .read(desktopIntegrationProvider)
                              .openUrl('https://github.com/vqh2602/paste_plus'),
                          child: const FaIcon(
                            FontAwesomeIcons.github,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        onPressed: update.isActive
                            ? null
                            : () => ref
                                  .read(updateDownloadProvider.notifier)
                                  .checkAndDownload(),
                        child: update.status == UpdateDownloadStatus.checking
                            ? const CupertinoActivityIndicator(radius: 8)
                            : Text(context.l10n.check_update),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Progress / status row ──────────────────────────────────────
              if (update.status != UpdateDownloadStatus.idle) ...[
                const SizedBox(height: 14),
                _UpdateStatusRow(update: update),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SettingsGroupWidget(
          children: [
            SettingsTileWidget(
              title: context.l10n.privacy_policy,
              subtitle: context.l10n.privacy_policy_sub,
              leading: const Icon(
                CupertinoIcons.shield_fill,
                color: CupertinoColors.activeGreen,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => showPrivacyPolicyDialog(context),
                child: Text(context.l10n.view_policy),
              ),
            ),
            SettingsTileWidget(
              title: context.l10n.open_source_licenses,
              subtitle: context.l10n.licenses_sub,
              leading: const Icon(
                CupertinoIcons.doc_plaintext,
                color: CupertinoColors.activeBlue,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => showLicensesDialog(context),
                child: Text(context.l10n.view_licenses),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _UpdateStatusRow extends StatelessWidget {
  const _UpdateStatusRow({required this.update});

  final UpdateDownloadState update;

  @override
  Widget build(BuildContext context) {
    final secondary = resolveColor(context, ClipFlowColors.secondaryText);
    final primary = CupertinoTheme.of(context).primaryColor;

    switch (update.status) {
      case UpdateDownloadStatus.checking:
        return Row(
          children: [
            const CupertinoActivityIndicator(radius: 7),
            const SizedBox(width: 8),
            Text(
              'Đang kiểm tra cập nhật…',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
        );

      case UpdateDownloadStatus.updateAvailable:
        return Row(
          children: [
            Icon(CupertinoIcons.arrow_down_circle, size: 14, color: primary),
            const SizedBox(width: 6),
            Text(
              'Tìm thấy ${update.latestVersion} — đang chuẩn bị tải…',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
        );

      case UpdateDownloadStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: update.progress > 0 ? update.progress : null,
                minHeight: 4,
                color: primary,
                backgroundColor: primary.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              update.progress > 0
                  ? 'Đang tải ${update.latestVersion}… ${(update.progress * 100).round()}%'
                  : 'Đang tải ${update.latestVersion}…',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
        );

      case UpdateDownloadStatus.done:
        return Row(
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 14,
              color: CupertinoColors.activeGreen,
            ),
            const SizedBox(width: 6),
            Text(
              'Đã tải ${update.latestVersion}. Đang khởi động lại…',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
        );

      case UpdateDownloadStatus.failed:
        return Row(
          children: [
            const Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 14,
              color: CupertinoColors.destructiveRed,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                update.errorMessage ?? 'Cập nhật thất bại',
                style: TextStyle(fontSize: 12, color: secondary),
              ),
            ),
          ],
        );

      case UpdateDownloadStatus.upToDate:
        return Row(
          children: [
            const Icon(
              CupertinoIcons.checkmark_seal_fill,
              size: 14,
              color: CupertinoColors.activeGreen,
            ),
            const SizedBox(width: 6),
            Text(
              'Bạn đang dùng phiên bản mới nhất',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
        );

      case UpdateDownloadStatus.idle:
        return const SizedBox.shrink();
    }
  }
}
