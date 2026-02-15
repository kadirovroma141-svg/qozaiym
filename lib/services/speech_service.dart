import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/material.dart';

class SpeechService {
  late stt.SpeechToText _speech;
  bool _isInitialized = false;

  SpeechService() {
    _speech = stt.SpeechToText();
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) => debugPrint('Speech Status: $status'),
        onError: (error) => debugPrint('Speech Error: $error'),
      );
      return _isInitialized;
    } catch (e) {
      debugPrint("Speech Init Error: $e");
      return false;
    }
  }

  Future<void> startListening({
    required Function(String text) onResult,
    String localeId = "ru_RU",
  }) async {
    if (!_isInitialized) {
      bool init = await initialize();
      if (!init) return;
    }

    if (!_speech.isListening) {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
          }
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  bool get isListening => _speech.isListening;
}
