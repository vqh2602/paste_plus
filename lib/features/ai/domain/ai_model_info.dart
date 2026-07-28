class AiModelInfo {
  const AiModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.parameterSize,
    required this.fileSizeMb,
    required this.downloadUrl,
    required this.recommendedFor,
    this.isThinkingModel = true,
    this.contextWindow = 8192,
  });

  final String id;
  final String name;
  final String description;
  final String parameterSize;
  final int fileSizeMb;
  final String downloadUrl;
  final String recommendedFor;
  final bool isThinkingModel;
  final int contextWindow;

  String get fileSizeFormatted {
    if (fileSizeMb >= 1000) {
      final gb = (fileSizeMb / 1024).toStringAsFixed(1);
      return '$gb GB';
    }
    return '$fileSizeMb MB';
  }

  static const List<AiModelInfo> thinkingModels = [
    AiModelInfo(
      id: 'deepseek-r1-1.5b',
      name: 'DeepSeek-R1-Distill-Qwen-1.5B (Thinking)',
      description: 'Model suy luận (thinking) nhẹ nhất, tốc độ phản hồi cực nhanh, phù hợp cho máy cấu hình vừa.',
      parameterSize: '1.5B',
      fileSizeMb: 1120,
      downloadUrl:
          'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
      recommendedFor: 'Tóm tắt nhanh, viết lại, sửa chính tả, Smart Reply',
    ),
    AiModelInfo(
      id: 'deepseek-r1-7b',
      name: 'DeepSeek-R1-Distill-Qwen-7B (Thinking)',
      description: 'Model suy luận chuyên sâu thế hệ mới, phân tích logic cao, giải thích code và lỗi kỹ thuật vượt trội.',
      parameterSize: '7B',
      fileSizeMb: 4480,
      downloadUrl:
          'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
      recommendedFor: 'Phân tích code, giải thích bug, trích xuất dữ liệu phức tạp',
    ),
    AiModelInfo(
      id: 'deepseek-r1-8b',
      name: 'DeepSeek-R1-Distill-Llama-8B (Thinking)',
      description: 'Model suy luận dựa trên Llama-3 architecture, độ chính xác cao khi xử lý văn bản dài và lập luận phức tạp.',
      parameterSize: '8B',
      fileSizeMb: 4920,
      downloadUrl:
          'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Llama-8B-GGUF/resolve/main/DeepSeek-R1-Distill-Llama-8B-Q4_K_M.gguf',
      recommendedFor: 'Soạn thảo email, bài viết dài, trích xuất JSON/Table',
    ),
    AiModelInfo(
      id: 'qwen2.5-coder-7b',
      name: 'Qwen2.5-Coder-7B-Instruct (Thinking / Code)',
      description: 'Model chuyên biệt về Code & Logic suy luận, cực kỳ mạnh mẽ trong việc đơn giản hóa code và refactor.',
      parameterSize: '7B',
      fileSizeMb: 4680,
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf',
      recommendedFor: 'Code explanation, refactoring, debug log analysis',
    ),
    AiModelInfo(
      id: 'qwen2.5-1.5b',
      name: 'Qwen2.5-1.5B-Instruct (Thinking)',
      description: 'Model siêu nhẹ chạy trực tiếp trên RAM thấp, đa ngôn ngữ mượt mà từ Việt sang Anh và ngược lại.',
      parameterSize: '1.5B',
      fileSizeMb: 980,
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      recommendedFor: 'Dịch thuật, phân loại thông minh, tạo tiêu đề & tag',
    ),
  ];

  static AiModelInfo findById(String id) {
    return thinkingModels.firstWhere(
      (m) => m.id == id,
      orElse: () => thinkingModels.first,
    );
  }
}
