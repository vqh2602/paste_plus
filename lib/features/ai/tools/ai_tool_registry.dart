import 'ai_tool.dart';

/// Central registry managing all registered AI Tools in ClipFlow.
class AiToolRegistry {
  AiToolRegistry();

  final Map<String, AiTool> _tools = {};

  /// Registers a tool into the registry.
  void register(AiTool tool) {
    _tools[tool.name] = tool;
  }

  /// Retrieves a registered tool by name.
  AiTool? getTool(String name) => _tools[name];

  /// Returns all registered tools.
  List<AiTool> allTools() => _tools.values.toList();

  /// Executes a registered tool by name.
  Future<AiToolResult> execute(
    String toolName,
    Map<String, dynamic> arguments, {
    Future<bool> Function(String toolName, Map<String, dynamic> arguments)?
        onConfirmationRequested,
  }) async {
    final tool = getTool(toolName);
    if (tool == null) {
      return AiToolResult.error('Tool "$toolName" không tồn tại trong hệ thống.');
    }

    // Fix #9: Fail-closed — never execute mutating tools without confirmation callback
    if (tool.requiresConfirmation) {
      if (onConfirmationRequested == null) {
        return AiToolResult.cancelled(
          'Không thể thực thi "$toolName": chưa có cơ chế xác nhận từ người dùng.',
        );
      }
      final approved = await onConfirmationRequested(toolName, arguments);
      if (!approved) {
        return AiToolResult.cancelled(
          'Người dùng đã từ chối thao tác "$toolName".',
        );
      }
    }

    try {
      return await tool.execute(arguments);
    } catch (e) {
      return AiToolResult.error('Lỗi khi thực thi tool "$toolName": $e');
    }
  }

  /// Returns JSON tool definitions suitable for LLM function calling schemas.
  List<Map<String, dynamic>> toToolDefinitions() {
    return _tools.values.map((tool) {
      return {
        'name': tool.name,
        'description': tool.description,
        'requires_confirmation': tool.requiresConfirmation,
        'parameters': tool.inputSchema,
      };
    }).toList();
  }
}
