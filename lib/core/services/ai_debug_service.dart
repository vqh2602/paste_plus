import 'package:flutter_riverpod/legacy.dart';

enum AiDebugLevel { info, success, warning, error }

class AiDebugEntry {
  const AiDebugEntry({
    required this.timestamp,
    required this.level,
    required this.stage,
    required this.message,
    this.requestId,
    this.details,
  });

  final DateTime timestamp;
  final AiDebugLevel level;
  final String stage;
  final String message;
  final String? requestId;
  final String? details;

  String get formatted {
    final time = timestamp.toIso8601String();
    final request = requestId == null ? '' : ' [request:$requestId]';
    final detailText = details?.trim().isNotEmpty == true
        ? '\n${details!.trim()}'
        : '';
    return '[$time] [${level.name.toUpperCase()}] [$stage]$request '
        '$message$detailText';
  }
}

class AiDebugState {
  const AiDebugState({this.isEnabled = false, this.entries = const []});

  final bool isEnabled;
  final List<AiDebugEntry> entries;

  AiDebugState copyWith({bool? isEnabled, List<AiDebugEntry>? entries}) {
    return AiDebugState(
      isEnabled: isEnabled ?? this.isEnabled,
      entries: entries ?? this.entries,
    );
  }
}

class AiDebugController extends StateNotifier<AiDebugState> {
  AiDebugController() : super(const AiDebugState());

  static const _unlockTapCount = 10;
  static const _maximumEntries = 400;
  static const _maximumDetailCharacters = 50000;
  var _iconTapCount = 0;

  /// Returns true whenever the hidden debug mode changes state.
  bool registerAppIconTap() {
    _iconTapCount++;
    if (_iconTapCount < _unlockTapCount) return false;
    _iconTapCount = 0;
    final enabled = !state.isEnabled;
    state = state.copyWith(isEnabled: enabled);
    if (enabled) {
      log(
        level: AiDebugLevel.success,
        stage: 'debug',
        message: 'AI Debug đã được bật',
        details: 'Log chỉ được lưu trong bộ nhớ và sẽ mất khi đóng ứng dụng.',
      );
    }
    return true;
  }

  void disable() {
    _iconTapCount = 0;
    state = state.copyWith(isEnabled: false);
  }

  void clear() {
    state = state.copyWith(entries: const []);
  }

  void log({
    required AiDebugLevel level,
    required String stage,
    required String message,
    String? requestId,
    String? details,
  }) {
    if (!state.isEnabled) return;
    final normalizedDetails = details == null
        ? null
        : details.length <= _maximumDetailCharacters
        ? details
        : '${details.substring(0, _maximumDetailCharacters)}\n'
              '… [đã cắt ${details.length - _maximumDetailCharacters} ký tự]';
    final entries = [
      ...state.entries,
      AiDebugEntry(
        timestamp: DateTime.now(),
        level: level,
        stage: stage,
        message: message,
        requestId: requestId,
        details: normalizedDetails,
      ),
    ];
    state = state.copyWith(
      entries: entries.length <= _maximumEntries
          ? entries
          : entries.sublist(entries.length - _maximumEntries),
    );
  }

  String exportText() =>
      state.entries.map((entry) => entry.formatted).join('\n\n');
}
