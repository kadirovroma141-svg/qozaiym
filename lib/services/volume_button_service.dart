import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:flutter_tts/flutter_tts.dart';


class VolumeButtonService {
  final VolumeController _volumeController = VolumeController();
  final Function(bool isUp) onVolumeButtonPressed;
  final Function onLongPressVolumeUp; 
  final Function onLongPressVolumeDown; 
  final FlutterTts? tts;

  double _lastVolume = 0.5;
  DateTime? _lastPressTime;
  bool _isLongPressDetected = false;

  VolumeButtonService({
    required this.onVolumeButtonPressed,
    required this.onLongPressVolumeUp,
    required this.onLongPressVolumeDown,
    this.tts,
  });

  Future<void> initialize() async {
    
    _lastVolume = await _volumeController.getVolume();
    debugPrint("VolumeButton: Initial volume: $_lastVolume");

    
    _volumeController.listener((volume) {
      _handleVolumeChange(volume);
    });

    debugPrint("VolumeButton: Service initialized");
  }

  void _handleVolumeChange(double newVolume) async {
    
    if (newVolume == _lastVolume) return;

    bool isVolumeUp = newVolume > _lastVolume;
    debugPrint(
        "VolumeButton: Volume changed from $_lastVolume to $newVolume (${isVolumeUp ? 'UP' : 'DOWN'})");

    
    
    

    
    DateTime now = DateTime.now();

    
    if (_lastPressTime != null &&
        now.difference(_lastPressTime!).inMilliseconds < 150) {
      _lastVolume = newVolume;
      _lastPressTime = now;
      return;
    }

    bool isLongPress = _lastPressTime != null &&
        now.difference(_lastPressTime!).inMilliseconds <
            500; 

    if (isLongPress && !_isLongPressDetected) {
      _isLongPressDetected = true;
      debugPrint(
          "VolumeButton: Long press/Double click detected (${isVolumeUp ? 'UP' : 'DOWN'})");

      if (isVolumeUp) {
        await tts?.speak("Вызов волонтера");
        onLongPressVolumeUp();
      } else {
        await tts?.speak("С О С");
        onLongPressVolumeDown();
      }

      
      Future.delayed(const Duration(milliseconds: 1000), () {
        _isLongPressDetected = false;
      });
    } else {
      
      debugPrint("VolumeButton: Normal press (${isVolumeUp ? 'UP' : 'DOWN'})");
      onVolumeButtonPressed(isVolumeUp);
    }

    _lastPressTime = now;
    
    
  }

  void dispose() {
    _volumeController.removeListener();
    debugPrint("VolumeButton: Service disposed");
  }
}
