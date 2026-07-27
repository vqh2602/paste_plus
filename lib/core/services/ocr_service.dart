import 'package:flutter/services.dart';

class OcrService {
  const OcrService();

  static const MethodChannel _channel = MethodChannel('clipflow/ocr');

  /// Extract text from an image file path using native OCR.
  Future<String?> extractTextFromImage(String imagePath) async {
    try {
      final String? result = await _channel.invokeMethod<String>(
        'performOcr',
        <String, dynamic>{'imagePath': imagePath},
      );
      if (result == null || result.trim().isEmpty) {
        return null;
      }
      return result.trim();
    } on PlatformException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }
}
