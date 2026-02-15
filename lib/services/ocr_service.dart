import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/material.dart';

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer(
      script: TextRecognitionScript
          .latin); 
  bool _isProcessing = false;

  Future<String> processImage(InputImage inputImage) async {
    if (_isProcessing) return "";
    _isProcessing = true;

    try {
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      _isProcessing = false;
      return recognizedText.text;
    } catch (e) {
      debugPrint("OCR Error: $e");
      _isProcessing = false;
      return "";
    }
  }

  String? detectCurrency(String text) {
    
    
    debugPrint("OCR: Searching for currency in text: $text");

    
    final RegExp currencyPattern =
        RegExp(r'\b(50|100|200|500|1000|2000|5000|10000|20000)\b');

    final matches = currencyPattern.allMatches(text);
    if (matches.isNotEmpty) {
      
      List<int> values = matches.map((m) => int.parse(m.group(0)!)).toList();
      values.sort();
      int value = values.last;

      debugPrint("OCR: Detected currency value: $value");
      return "$value";
    }

    debugPrint("OCR: No currency value detected");
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
