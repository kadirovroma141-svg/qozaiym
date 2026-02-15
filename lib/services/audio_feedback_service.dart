import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class AudioFeedbackService {
  final AudioPlayer _player = AudioPlayer();
  String? _beepFilePath;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    
    
    _beepFilePath = await _createBeepFile();

    
    if (_beepFilePath != null) {
      await _player.setSource(DeviceFileSource(_beepFilePath!));
      await _player.setReleaseMode(ReleaseMode.stop);
    }
    _isInitialized = true;
  }

  Future<String> _createBeepFile() async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/sonar_beep.wav');

    if (await file.exists()) return file.path;

    
    
    
    

    int sampleRate = 8000;
    int durationMs = 150;
    int numSamples = (sampleRate * durationMs / 1000).round();
    int dataSize = numSamples;
    int fileSize = 36 + dataSize;

    var bytes = BytesBuilder();

    
    bytes.add('RIFF'.codeUnits);
    bytes.add(_int32(fileSize));
    bytes.add('WAVE'.codeUnits);

    
    bytes.add('fmt '.codeUnits);
    bytes.add(_int32(16)); 
    bytes.add(_int16(1)); 
    bytes.add(_int16(1)); 
    bytes.add(_int32(sampleRate));
    bytes.add(_int32(
        sampleRate)); 
    bytes.add(_int16(1)); 
    bytes.add(_int16(8)); 

    
    bytes.add('data'.codeUnits);
    bytes.add(_int32(dataSize));

    
    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      
      int sample = (127 + 127 * sin(t * 880 * 2 * 3.14159)).toInt();
      bytes.addByte(sample);
    }

    await file.writeAsBytes(bytes.toBytes());
    return file.path;
  }

  List<int> _int32(int value) {
    var b = ByteData(4);
    b.setInt32(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  List<int> _int16(int value) {
    var b = ByteData(2);
    b.setInt16(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  Future<void> playSonar(
      {required double balance, required double volume}) async {
    if (!_isInitialized || _beepFilePath == null) return;

    if (_player.state == PlayerState.playing) {
      
      
      await _player.stop();
    }

    await _player.setBalance(balance); 
    await _player.setVolume(volume.clamp(0.0, 1.0));
    await _player.resume();
    
    
  }

  void dispose() {
    _player.dispose();
  }
}
