/// Represents the execution outcome of an [AiTool].
class AiToolResult {
  const AiToolResult({
    required this.success,
    required this.output,
    this.data,
    this.cancelled = false,
  });

  factory AiToolResult.ok(String output, [dynamic data]) =>
      AiToolResult(success: true, output: output, data: data);

  factory AiToolResult.error(String message) =>
      AiToolResult(success: false, output: message);

  factory AiToolResult.notFound(String message) =>
      AiToolResult(success: false, output: message);

  factory AiToolResult.cancelled(String reason) =>
      AiToolResult(success: false, output: reason, cancelled: true);

  final bool success;
  final String output;
  final dynamic data;
  final bool cancelled;

  Map<String, dynamic> toJson() => {
        'success': success,
        'output': output,
        'data': data,
        'cancelled': cancelled,
      };
}

/// Abstract contract for all ClipFlow AI Tools.
abstract interface class AiTool {
  String get name;
  String get description;
  bool get requiresConfirmation;
  Map<String, dynamic> get inputSchema;

  Future<AiToolResult> execute(Map<String, dynamic> arguments);
}
