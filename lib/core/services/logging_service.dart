import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class LoggingService {
  const LoggingService();

  void log(
    LogLevel level,
    String message, {
    String? itemId,
    String? contentType,
    int? contentSize,
    Object? error,
  }) {
    if (kReleaseMode && level == LogLevel.debug) return;
    final safeMetadata = [
      if (itemId != null) 'item=$itemId',
      if (contentType != null) 'type=$contentType',
      if (contentSize != null) 'size=$contentSize',
      if (error != null) 'error=${error.runtimeType}',
    ].join(' ');
    debugPrint('[ClipFlow/${level.name}] $message $safeMetadata');
  }
}
