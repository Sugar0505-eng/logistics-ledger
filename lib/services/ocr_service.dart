import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'container_number.dart';

/// 端上 OCR 服务：拍照/选图 → ML Kit 离线文字识别 → 提取候选柜号。
class OcrService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// 拍照或从相册选图并识别，返回候选柜号（校验通过者在前）。
  /// 用户取消选图返回 null。
  Future<OcrResult?> pickAndRecognize(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source);
    if (file == null) return null;

    final input = InputImage.fromFilePath(file.path);
    final recognized = await _recognizer.processImage(input);
    final candidates = ContainerNumber.extractCandidates(recognized.text);
    return OcrResult(rawText: recognized.text, candidates: candidates);
  }

  void dispose() => _recognizer.close();
}

class OcrResult {
  OcrResult({required this.rawText, required this.candidates});

  final String rawText;
  final List<String> candidates;

  /// 最可能的柜号（候选已按校验状态排序）。
  String? get best => candidates.isEmpty ? null : candidates.first;
}
