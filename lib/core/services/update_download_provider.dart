import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import './update_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum UpdateDownloadStatus {
  idle,
  checking,
  upToDate, // no new version
  updateAvailable, // new version found, not yet downloading
  downloading,
  done,
  failed,
}

class UpdateDownloadState {
  const UpdateDownloadState({
    this.status = UpdateDownloadStatus.idle,
    this.latestVersion,
    this.progress = 0,
    this.errorMessage,
  });

  final UpdateDownloadStatus status;
  final String? latestVersion; // e.g. "v2.0.1"
  final double progress; // 0.0 – 1.0
  final String? errorMessage;

  bool get isActive =>
      status == UpdateDownloadStatus.checking ||
      status == UpdateDownloadStatus.downloading;

  bool get hasChecked =>
      status != UpdateDownloadStatus.idle &&
      status != UpdateDownloadStatus.checking;

  UpdateDownloadState copyWith({
    UpdateDownloadStatus? status,
    String? latestVersion,
    double? progress,
    String? errorMessage,
  }) {
    return UpdateDownloadState(
      status: status ?? this.status,
      latestVersion: latestVersion ?? this.latestVersion,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class UpdateDownloadController extends StateNotifier<UpdateDownloadState> {
  UpdateDownloadController() : super(const UpdateDownloadState());

  /// Check for update and, if available, download + install in the background.
  /// Safe to call even when the UI widget is disposed.
  Future<void> checkAndDownload() async {
    if (state.isActive) return; // already running

    state = state.copyWith(status: UpdateDownloadStatus.checking);

    final info = await UpdateService().checkForUpdate();

    if (info == null) {
      state = state.copyWith(
        status: UpdateDownloadStatus.failed,
        errorMessage: 'Không thể kiểm tra cập nhật',
      );
      return;
    }

    if (!info.hasUpdate) {
      state = state.copyWith(status: UpdateDownloadStatus.upToDate);
      return;
    }

    // Clean version string (remove leading 'v' duplicates from tag name)
    final versionDisplay = info.latestVersion.startsWith('v')
        ? info.latestVersion
        : 'v${info.latestVersion}';

    state = state.copyWith(
      status: UpdateDownloadStatus.updateAvailable,
      latestVersion: versionDisplay,
    );

    if (info.downloadUrl == null) {
      state = state.copyWith(
        status: UpdateDownloadStatus.failed,
        errorMessage: 'Không tìm thấy file tải',
      );
      return;
    }

    // Start background download
    state = state.copyWith(
      status: UpdateDownloadStatus.downloading,
      progress: 0,
    );

    final success = await UpdateService().downloadAndInstallUpdate(
      downloadUrl: info.downloadUrl!,
      onProgress: (p) {
        // Update state regardless of whether any UI is mounted.
        state = state.copyWith(progress: p);
      },
    );

    state = state.copyWith(
      status: success ? UpdateDownloadStatus.done : UpdateDownloadStatus.failed,
      errorMessage: success ? null : 'Cập nhật thất bại. Vui lòng thử lại.',
    );
  }

  /// Only checks version without downloading. Good for auto-triggering on screen open.
  Future<void> checkOnly() async {
    if (state.isActive || state.hasChecked) return; // already done or running

    state = state.copyWith(status: UpdateDownloadStatus.checking);

    final info = await UpdateService().checkForUpdate();

    if (info == null) {
      state = state.copyWith(
        status: UpdateDownloadStatus.failed,
        errorMessage: 'Không thể kiểm tra cập nhật',
      );
      return;
    }

    if (!info.hasUpdate) {
      state = state.copyWith(status: UpdateDownloadStatus.upToDate);
      return;
    }

    final versionDisplay = info.latestVersion.startsWith('v')
        ? info.latestVersion
        : 'v${info.latestVersion}';

    state = state.copyWith(
      status: UpdateDownloadStatus.updateAvailable,
      latestVersion: versionDisplay,
    );
  }

  /// Reset to idle so the user can check again.
  void reset() => state = const UpdateDownloadState();
}

// ---------------------------------------------------------------------------
// Provider (app-level singleton — survives widget disposal)
// ---------------------------------------------------------------------------

final updateDownloadProvider =
    StateNotifierProvider<UpdateDownloadController, UpdateDownloadState>(
      (ref) => UpdateDownloadController(),
    );
