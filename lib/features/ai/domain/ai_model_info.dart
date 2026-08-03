import '../../../core/localization/app_translations.dart';

class AiModelInfo {
  static const defaultModelId = 'gemma-4-e2b';

  const AiModelInfo({
    required this.id,
    required this.name,
    required String description,
    required this.parameterSize,
    required this.fileSizeMb,
    required this.downloadUrl,
    required String recommendedFor,
    this.sha256,
    this.quantization = 'Q4_0',
    this.license = 'Gemma / Apache 2.0',
    this.isThinkingModel = true,
    this.isMultimodal = false,
    this.mmprojUrl,
    this.contextWindow = 8192,
  })  : _rawDescription = description,
        _rawRecommendedFor = recommendedFor;

  final String id;
  final String name;
  final String _rawDescription;
  final String parameterSize;
  final int fileSizeMb;
  final String downloadUrl;
  final String _rawRecommendedFor;
  final String? sha256;
  final String quantization;
  final String license;
  final bool isThinkingModel;
  final bool isMultimodal;
  final String? mmprojUrl;
  final int contextWindow;

  String get description {
    final isEn = AppTranslations.currentLanguage == 'en';
    return switch (id) {
      'gemma-4-e2b' => isEn
          ? "Google's next-gen multilingual model, optimized for conversation and local processing."
          : 'Model đa ngôn ngữ thế hệ mới của Google, tối ưu cho hội thoại và xử lý cục bộ trên thiết bị.',
      'gemma-4-e4b' => isEn
          ? 'Stronger Gemma 4 model for complex questions, longer reasoning, and higher precision.'
          : 'Bản Gemma 4 mạnh hơn dành cho câu hỏi phức tạp, lập luận dài và độ chính xác cao hơn.',
      'qwen3-0.6b' => isEn
          ? 'Ultra-lightweight model with fast response and good multilingual support on low-RAM devices.'
          : 'Model cực nhẹ, phản hồi nhanh và hỗ trợ đa ngôn ngữ tốt trên máy có ít RAM.',
      'deepseek-r1-1.5b' => isEn
          ? 'Lightest reasoning model with ultra-fast speed, ideal for mid-tier devices.'
          : 'Model suy luận (thinking) nhẹ nhất, tốc độ phản hồi cực nhanh, phù hợp cho máy cấu hình vừa.',
      'deepseek-r1-7b' => isEn
          ? 'Advanced reasoning model with strong logic, code explanation, and error diagnosis.'
          : 'Model suy luận chuyên sâu thế hệ mới, phân tích logic cao, giải thích code và lỗi kỹ thuật vượt trội.',
      'deepseek-r1-8b' => isEn
          ? 'Llama-3 based reasoning model, highly accurate for long documents and complex logic.'
          : 'Model suy luận dựa trên Llama-3 architecture, độ chính xác cao khi xử lý văn bản dài và lập luận phức tạp.',
      'qwen2.5-coder-7b' => isEn
          ? 'Specialized Code & Logic model, highly effective for code simplification and refactoring.'
          : 'Model chuyên biệt về Code & Logic suy luận, cực kỳ mạnh mẽ trong việc đơn giản hóa code và refactor.',
      'qwen2.5-1.5b' => isEn
          ? 'Ultra-lightweight model running directly on low RAM, smooth translation between languages.'
          : 'Model siêu nhẹ chạy trực tiếp trên RAM thấp, đa ngôn ngữ mượt mà từ Việt sang Anh và ngược lại.',
      _ => _rawDescription,
    };
  }

  String get recommendedFor {
    final isEn = AppTranslations.currentLanguage == 'en';
    return switch (id) {
      'gemma-4-e2b' => isEn
          ? 'Daily chat, Clipboard Q&A, summary and translation'
          : 'Chat hằng ngày, hỏi đáp Clipboard, tóm tắt và dịch thuật',
      'gemma-4-e4b' => isEn
          ? 'Deep Q&A, long text analysis and complex tasks'
          : 'Hỏi đáp chuyên sâu, phân tích nội dung dài và tác vụ phức tạp',
      'qwen3-0.6b' => isEn
          ? 'Quick chat, classification, titles and short tasks'
          : 'Chat nhanh, phân loại, tiêu đề và tác vụ ngắn',
      'deepseek-r1-1.5b' => isEn
          ? 'Quick summary, rewrite, grammar check, Smart Reply'
          : 'Tóm tắt nhanh, viết lại, sửa chính tả, Smart Reply',
      'deepseek-r1-7b' => isEn
          ? 'Code analysis, bug explanation, complex data extraction'
          : 'Phân tích code, giải thích bug, trích xuất dữ liệu phức tạp',
      'deepseek-r1-8b' => isEn
          ? 'Drafting emails, long articles, JSON/Table extraction'
          : 'Soạn thảo email, bài viết dài, trích xuất JSON/Table',
      _ => _rawRecommendedFor,
    };
  }

  String get fileSizeFormatted {
    if (fileSizeMb >= 1000) {
      final gb = (fileSizeMb / 1024).toStringAsFixed(1);
      return '$gb GB';
    }
    return '$fileSizeMb MB';
  }

  static const List<AiModelInfo> thinkingModels = [
    AiModelInfo(
      id: 'gemma-4-e2b',
      name: 'Gemma 4 E2B Instruct',
      description:
          'Model đa ngôn ngữ thế hệ mới của Google, tối ưu cho hội thoại và xử lý cục bộ trên thiết bị.',
      parameterSize: 'E2B',
      fileSizeMb: 3195,
      downloadUrl:
          'https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/main/gemma-4-E2B_q4_0-it.gguf',
      recommendedFor:
          'Chat hằng ngày, hỏi đáp Clipboard, tóm tắt và dịch thuật',
      contextWindow: 32768,
    ),
    AiModelInfo(
      id: 'gemma-4-e4b',
      name: 'Gemma 4 E4B Instruct',
      description:
          'Bản Gemma 4 mạnh hơn dành cho câu hỏi phức tạp, lập luận dài và độ chính xác cao hơn.',
      parameterSize: 'E4B',
      fileSizeMb: 4917,
      downloadUrl:
          'https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/main/gemma-4-E4B_q4_0-it.gguf',
      recommendedFor:
          'Hỏi đáp chuyên sâu, phân tích nội dung dài và tác vụ phức tạp',
      contextWindow: 32768,
    ),
    AiModelInfo(
      id: 'qwen3-0.6b',
      name: 'Qwen3 0.6B',
      description:
          'Model cực nhẹ, phản hồi nhanh và hỗ trợ đa ngôn ngữ tốt trên máy có ít RAM.',
      parameterSize: '0.6B',
      fileSizeMb: 610,
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf',
      recommendedFor: 'Chat nhanh, phân loại, tiêu đề và tác vụ ngắn',
      contextWindow: 32768,
    ),
    AiModelInfo(
      id: 'deepseek-r1-1.5b',
      name: 'DeepSeek-R1-Distill-Qwen-1.5B (Thinking)',
      description:
          'Model suy luận (thinking) nhẹ nhất, tốc độ phản hồi cực nhanh, phù hợp cho máy cấu hình vừa.',
      parameterSize: '1.5B',
      fileSizeMb: 1120,
      downloadUrl:
          'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
      recommendedFor: 'Tóm tắt nhanh, viết lại, sửa chính tả, Smart Reply',
    ),
    AiModelInfo(
      id: 'deepseek-r1-7b',
      name: 'DeepSeek-R1-Distill-Qwen-7B (Thinking)',
      description:
          'Model suy luận chuyên sâu thế hệ mới, phân tích logic cao, giải thích code và lỗi kỹ thuật vượt trội.',
      parameterSize: '7B',
      fileSizeMb: 4480,
      downloadUrl:
          'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
      recommendedFor:
          'Phân tích code, giải thích bug, trích xuất dữ liệu phức tạp',
    ),
    AiModelInfo(
      id: 'deepseek-r1-8b',
      name: 'DeepSeek-R1-Distill-Llama-8B (Thinking)',
      description:
          'Model suy luận dựa trên Llama-3 architecture, độ chính xác cao khi xử lý văn bản dài và lập luận phức tạp.',
      parameterSize: '8B',
      fileSizeMb: 4920,
      downloadUrl:
          'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Llama-8B-GGUF/resolve/main/DeepSeek-R1-Distill-Llama-8B-Q4_K_M.gguf',
      recommendedFor: 'Soạn thảo email, bài viết dài, trích xuất JSON/Table',
    ),
    AiModelInfo(
      id: 'qwen2.5-coder-7b',
      name: 'Qwen2.5-Coder-7B-Instruct (Thinking / Code)',
      description:
          'Model chuyên biệt về Code & Logic suy luận, cực kỳ mạnh mẽ trong việc đơn giản hóa code và refactor.',
      parameterSize: '7B',
      fileSizeMb: 4680,
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf',
      recommendedFor: 'Code explanation, refactoring, debug log analysis',
    ),
    AiModelInfo(
      id: 'qwen2.5-1.5b',
      name: 'Qwen2.5-1.5B-Instruct (Thinking)',
      description:
          'Model siêu nhẹ chạy trực tiếp trên RAM thấp, đa ngôn ngữ mượt mà từ Việt sang Anh và ngược lại.',
      parameterSize: '1.5B',
      fileSizeMb: 980,
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      recommendedFor: 'Dịch thuật, phân loại thông minh, tạo tiêu đề & tag',
      isThinkingModel: false,
    ),
  ];

  static AiModelInfo findById(String id) {
    return thinkingModels.firstWhere(
      (m) => m.id == id,
      orElse: () => thinkingModels.first,
    );
  }
}

