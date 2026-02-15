import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'services/location_service.dart';
import 'services/speech_service.dart';
import 'services/navigation_service.dart';
import 'services/ocr_service.dart';
import 'services/audio_feedback_service.dart';
import 'services/sos_service.dart';
import 'services/ai_service.dart';
import 'services/webrtc_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/ai_confidence_service.dart';
import 'services/volume_button_service.dart'; 
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; 
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:async'; 
import 'theme/app_theme.dart';
import 'widgets/glass_container.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart'; 

class VisionPage extends StatefulWidget {
  const VisionPage({super.key});

  @override
  State<VisionPage> createState() => _VisionPageState();
}


class Obstacle {
  final String label;
  final double confidence;
  final Rect box;
  final String zone;
  final double distance;

  Obstacle({
    required this.label,
    required this.confidence,
    required this.box,
    required this.zone,
    required this.distance,
  });
}

enum VisionMode {
  navigation,
  text,
  currency,
}

class _VisionPageState extends State<VisionPage> {
  final LocationService _locationService = LocationService();
  final SpeechService _speechService = SpeechService();
  final NavigationService _navigationService = NavigationService();
  final OCRService _ocrService = OCRService();
  final AudioFeedbackService _audioFeedbackService = AudioFeedbackService();
  final SOSService _sosService = SOSService();
  final AIService _aiService = AIService();

  
  final WebRTCService _webrtcService = WebRTCService();
  final FirebaseSyncService _firebaseSyncService = FirebaseSyncService();
  final AIConfidenceService _aiConfidenceService = AIConfidenceService();

  
  VolumeButtonService? _volumeButtonService;

  StreamSubscription<CompassEvent>? _compassSubscription;
  double _currentHeading = 0.0;
  bool _isInVolunteerCall = false;
  int? _remoteVolunteerUid;

  VisionMode _currentMode = VisionMode.navigation;

  CameraController? _ocrController;
  bool _isOcrCameraReady = false;
  
  
  
  
  

  FlutterTts? _flutterTts;

  
  bool _isListening = false;
  List<RouteStep> _routeSteps = [];
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  List<Obstacle> _obstacles = [];
  String _navigationCommand = "Загрузка YOLO...";
  String _distanceInfo = "";
  bool _isReady = false;

  
  DateTime _lastSpeakTime = DateTime.now();
  final Duration _speakInterval = const Duration(milliseconds: 1500);
  String _lastSpokenCommand = "";

  
  String _spokenText = "";

  
  static const Map<String, double> _realObjectsHeight = {
    'person': 1.7,
    'bicycle': 1.0,
    'car': 1.5,
    'motorcycle': 1.0,
    'bus': 3.0,
    'train': 3.5,
    'truck': 2.5,
    'traffic light': 0.8, 
    'fire hydrant': 0.6,
    'stop sign': 0.8,
    'bench': 0.5,
    'cat': 0.3,
    'dog': 0.5,
    'backpack': 0.5,
    'chair': 0.6, 
    'bed': 0.6,
    'couch': 0.8,
    'dining table': 0.75,
    'toilet': 0.5,
    'sink': 0.85,
    'refrigerator': 1.8,
    'microwave': 0.4,
    'oven': 0.8,
    'potted plant': 0.5,
    'tv': 0.6,
    'laptop': 0.3,
  };

  
  static const double criticalDistanceMeters = 2.0; 
  static const double warningDistanceMeters = 4.0; 
  static const double cautionDistanceMeters = 6.0; 

  
  static const Set<String> obstacleLabels = {
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'bus',
    'train',
    'truck',
    'traffic light',
    'fire hydrant',
    'stop sign',
    'parking meter',
    'bench',
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'backpack',
    'umbrella',
    'handbag',
    'suitcase',
    'chair',
    'couch',
    'potted plant',
    'bed',
    'dining table',
    'toilet',
    'microwave',
    'oven',
    'toaster',
    'sink',
    'refrigerator',
    'skateboard',
    'surfboard',
    'sports ball',
    'bottle',
    'cup',
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _initializeTTS();
    await _audioFeedbackService.initialize();
    await _requestPermissions();

    
    await _initializePhase6();

    if (mounted) {
      setState(() {
        _isReady = true;
        _navigationCommand = "YOLO готов!";
      });

      
      _initVolumeButtons();
    }
  }

  Future<void> _initializePhase6() async {
    try {
      
      String userId = DateTime.now().millisecondsSinceEpoch.toString();
      _firebaseSyncService.setUserId(userId);
      debugPrint("Firebase user ID: $userId");

      
      _compassSubscription =
          FlutterCompass.events?.listen((CompassEvent event) {
        _currentHeading = event.heading ?? 0.0;
      });

      
      await _webrtcService.initialize();
      _webrtcService.onRemoteUserJoined = (uid) {
        if (mounted) {
          setState(() {
            _remoteVolunteerUid = uid;
          });
        }
        _flutterTts?.speak(" Волонтер подключился");
      };

      _webrtcService.onRemoteUserLeft = (uid) {
        if (mounted) {
          setState(() {
            _remoteVolunteerUid = null;
            _isInVolunteerCall = false;
          });
        }
        _flutterTts?.speak("Волонтер отключился");
      };

      debugPrint("Phase 6 initialized");
    } catch (e) {
      debugPrint("Phase 6 initialization error: $e");
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
  }

  Future<void> _initializeTTS() async {
    _flutterTts = FlutterTts();
    await _flutterTts?.setLanguage("ru-RU");
    await _flutterTts?.setSpeechRate(0.6); 
    await _flutterTts?.setVolume(1.0);
  }

  
  void _initVolumeButtons() {
    _volumeButtonService = VolumeButtonService(
      onVolumeButtonPressed: (isUp) {
        _handleVolumeButton(isUp);
      },
      onLongPressVolumeUp: () {
        _handleCall(); 
      },
      onLongPressVolumeDown: () {
        _sosService.sendSOS([]); 
      },
      tts: _flutterTts,
    );

    _volumeButtonService?.initialize();

    
    _flutterTts?.speak(
        "Приложение Навиблайнд. Свайп влево или вправо для смены режима. Тап по экрану для действия. Кнопки громкости также работают.");
  }

  void _handleVolumeButton(bool isUp) {
    if (isUp) {
      
      if (_currentMode == VisionMode.navigation) {
        _switchVisionMode(VisionMode.text);
      } else if (_currentMode == VisionMode.text) {
        _switchVisionMode(VisionMode.currency);
      } else {
        _switchVisionMode(VisionMode.navigation);
      }
    } else {
      
      if (_currentMode == VisionMode.navigation) {
        _switchVisionMode(VisionMode.currency);
      } else if (_currentMode == VisionMode.currency) {
        _switchVisionMode(VisionMode.text);
      } else {
        _switchVisionMode(VisionMode.navigation);
      }
    }
  }

  void _switchVisionMode(VisionMode newMode) {
    if (!mounted) return;

    setState(() {
      _currentMode = newMode;
    });

    
    String modeName = "";
    switch (newMode) {
      case VisionMode.navigation:
        modeName = "Режим навигации. Обнаружение препятствий.";
        break;
      case VisionMode.text:
        modeName = "Режим текста. Наведите камеру на текст.";
        break;
      case VisionMode.currency:
        modeName = "Режим купюры. Поднесите купюру к камере.";
        break;
    }

    _flutterTts?.speak(modeName);
    debugPrint("Mode switched to: $newMode");

    
    _manageCameraResources();
  }

  void _onYOLOResult(List<YOLOResult> results) {
    if (results.isEmpty) {
      if (mounted && _obstacles.isNotEmpty) {
        setState(() {
          _obstacles = [];
          _updateNavigation();
        });
      }
      return;
    }

    
    

    List<Obstacle> newObstacles = [];

    for (final result in results) {
      String label = result.className.toLowerCase();
      double confidence = result.confidence;

      if (confidence < 0.35) {
        continue; 
      }
      if (!obstacleLabels.contains(label)) continue;

      Rect box = result.normalizedBox;
      double distance = _estimateDistanceMeters(box, label);
      String zone = _getZone(box);

      newObstacles.add(Obstacle(
        label: label,
        confidence: confidence,
        box: box,
        zone: zone,
        distance: distance,
      ));
    }

    
    newObstacles.sort((a, b) => a.distance.compareTo(b.distance));

    if (mounted) {
      setState(() {
        _obstacles = newObstacles;
        _updateNavigation();
      });
      _provideFeedback();
      _updateSonar(newObstacles);
      _checkForBus(newObstacles);

      
      _checkAIConfidence(newObstacles);

      
      if (_isInVolunteerCall) {
        _syncToFirebase(newObstacles);
      }
    }
  }

  
  DateTime _lastConfidenceCheck =
      DateTime.now().subtract(const Duration(minutes: 1));

  void _checkAIConfidence(List<Obstacle> obstacles) {
    
    if (DateTime.now().difference(_lastConfidenceCheck).inSeconds < 30) return;

    
    if (_isInVolunteerCall) return;

    if (_aiConfidenceService.shouldSuggestVolunteer(obstacles)) {
      _lastConfidenceCheck = DateTime.now();
      _suggestVolunteerCall(obstacles);
    }
  }

  void _suggestVolunteerCall(List<Obstacle> obstacles) {
    String message = _aiConfidenceService.getExplanationMessage(obstacles);
    _flutterTts?.speak("$message. Позвонить волонтеру?");

    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Нужна помощь?"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Нет"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _callVolunteer();
            },
            child: const Text("Да, позвонить"),
          ),
        ],
      ),
    );
  }

  
  Future<void> _syncToFirebase(List<Obstacle> obstacles) async {
    try {
      
      await _firebaseSyncService.syncYOLOData(obstacles);

      
      Position? position = await _locationService.getCurrentPosition();
      if (position != null) {
        await _firebaseSyncService.syncLocation(position, _currentHeading);
      }

      
      await _firebaseSyncService.syncNavigationCommand(
          _navigationCommand, _currentMode.name);
    } catch (e) {
      debugPrint("Firebase sync error: $e");
    }
  }

  DateTime _lastBusCheck = DateTime.now().subtract(const Duration(minutes: 1));
  bool _isCheckingBus = false;

  void _checkForBus(List<Obstacle> obstacles) {
    if (_isCheckingBus) return;

    
    
    
    bool busFound =
        obstacles.any((o) => o.label == 'bus' && o.confidence > 0.6);

    if (busFound && DateTime.now().difference(_lastBusCheck).inSeconds > 20) {
      _identifyBus();
    }
  }

  Future<void> _identifyBus() async {
    _lastBusCheck = DateTime.now();
    _isCheckingBus = true;

    try {
      await _flutterTts?.speak("Вижу автобус. Проверяю номер...");
    } catch (e) {
      debugPrint("TTS error: $e");
    }

    debugPrint("Bus detection: Starting identification");

    VisionMode previousMode = _currentMode;

    try {
      debugPrint(
          "Bus detection: Previous mode: $previousMode, current: $_currentMode");
      debugPrint("Bus detection: Switching to Text mode");

      
      if (mounted) {
        setState(() {
          _currentMode = VisionMode.text;
        });
        debugPrint("Bus detection: setState completed");
      } else {
        debugPrint("Bus detection: Widget not mounted!");
        return;
      }

      
      debugPrint("Bus detection: Calling _manageCameraResources");
      await _manageCameraResources();

      
      debugPrint("Bus detection: Waiting for camera ready...");
      int waitCount = 0;
      while (!_isOcrCameraReady && waitCount < 50 && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
        if (waitCount % 10 == 0) {
          debugPrint(
              "Bus detection: Still waiting... ($waitCount/50), ready=$_isOcrCameraReady");
        }
      }

      debugPrint(
          "Bus detection: Camera ready status: $_isOcrCameraReady, controller: ${_ocrController != null}");

      if (!_isOcrCameraReady || _ocrController == null) {
        debugPrint("Bus detection: Camera not ready after waiting");
        throw "Camera not ready";
      }

      
      debugPrint("Bus detection: Waiting for camera stabilization...");
      await Future.delayed(
          const Duration(milliseconds: 1500)); 

      
      debugPrint("Bus detection: Taking picture");
      XFile pic = await _ocrController!.takePicture();
      debugPrint("Bus detection: Picture taken: ${pic.path}");

      
      debugPrint("Bus detection: Sending to AI");
      String? number = await _aiService.identifyBusNumber(pic.path);
      debugPrint("Bus detection: AI response: $number");

      if (number != null) {
        await _flutterTts?.speak("Это автобус номер $number");
      } else {
        await _flutterTts?.speak("Не удалось прочитать номер.");
      }
    } catch (e, stackTrace) {
      debugPrint("Bus check failed: $e");
      debugPrint("Stack trace: $stackTrace");
      try {
        await _flutterTts?.speak("Ошибка распознавания.");
      } catch (_) {}
    } finally {
      debugPrint("Bus detection: Returning to previous mode: $previousMode");
      
      try {
        if (mounted) {
          setState(() {
            _currentMode = previousMode;
          });
          await _manageCameraResources();
        }
      } catch (e) {
        debugPrint("Error in finally block: $e");
      }
      _isCheckingBus = false;
      debugPrint("Bus detection: Cleanup complete");
    }
  }

  
  Timer? _sonarTimer;

  void _updateSonar(List<Obstacle> obstacles) {
    _sonarTimer?.cancel();
    if (_currentMode != VisionMode.navigation || obstacles.isEmpty) return;

    Obstacle closest = obstacles.first; 
    if (closest.distance > 5.0) return; 

    
    
    
    double centerX = closest.box.center.dx;
    double balance = (centerX - 0.5) * 2; 

    
    
    
    int intervalMs = (closest.distance * 300).clamp(200, 1500).toInt();

    
    _sonarTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted || _currentMode != VisionMode.navigation) {
        timer.cancel();
        return;
      }
      _audioFeedbackService.playSonar(balance: balance, volume: 1.0);
    });
  }

  double _estimateDistanceMeters(Rect box, String label) {
    double realH =
        _realObjectsHeight[label] ?? 0.8; 
    double viewH = box.height;
    if (viewH <= 0) return 999.0;

    
    
    
    
    
    
    

    
    
    
    

    
    return realH / viewH;
  }

  String _getZone(Rect box) {
    double centerX = box.center.dx; 
    if (centerX < 0.35) return "left";
    if (centerX > 0.65) return "right";
    return "center";
  }

  void _updateNavigation() {
    if (_obstacles.isEmpty) {
      if (_isNavigating) {
        
        RouteStep? step = (_currentStepIndex < _routeSteps.length)
            ? _routeSteps[_currentStepIndex]
            : null;
        if (step != null) {
          _navigationCommand = "Маршрут: ${step.distance.toInt()}м";
          _distanceInfo = step.instruction;
        }
      } else {
        _navigationCommand = "ИДИ ПРЯМО";
        _distanceInfo = "";
      }
      return;
    }

    Obstacle closest = _obstacles.first;
    double dist = closest.distance;

    
    _distanceInfo =
        "${closest.label.toUpperCase()}: ${dist.toStringAsFixed(1)} м";

    if (dist < criticalDistanceMeters) {
      String dir = closest.zone == "left"
          ? "слева"
          : closest.zone == "right"
              ? "справа"
              : "впереди";
      _navigationCommand = "СТОЙ! ${closest.label} $dir";
      return;
    }

    
    bool leftBlocked = _obstacles
        .any((o) => o.zone == "left" && o.distance < warningDistanceMeters);
    bool centerBlocked = _obstacles
        .any((o) => o.zone == "center" && o.distance < warningDistanceMeters);
    bool rightBlocked = _obstacles
        .any((o) => o.zone == "right" && o.distance < warningDistanceMeters);

    if (!centerBlocked) {
      _navigationCommand = "ИДИ ПРЯМО";
    } else if (!leftBlocked && !rightBlocked) {
      
      
      _navigationCommand = "ОБОЙДИ (Влево/Вправо)";
      
      _navigationCommand = "ВПРАВО"; 
    } else if (!leftBlocked) {
      _navigationCommand = "ВЛЕВО";
    } else if (!rightBlocked) {
      _navigationCommand = "ВПРАВО";
    } else {
      _navigationCommand = "СТОЙ! Тупик";
    }
  }

  void _provideFeedback() async {
    final now = DateTime.now();
    if (now.difference(_lastSpeakTime) < _speakInterval) return;

    bool isUrgent = _navigationCommand.contains("СТОЙ");
    if (_navigationCommand == _lastSpokenCommand && !isUrgent) return;

    _lastSpeakTime = now;
    _lastSpokenCommand = _navigationCommand;

    String voice;
    if (_navigationCommand.contains("СТОЙ")) {
      voice = "Стой!";
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: [0, 300, 100, 300, 100, 300]);
      }
    } else if (_navigationCommand.contains("ВЛЕВО")) {
      voice = "Влево";
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: [0, 100, 50, 100]);
      }
    } else if (_navigationCommand.contains("ВПРАВО")) {
      voice = "Вправо";
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 100]);
      }
    } else if (_navigationCommand.contains("ПРЯМО")) {
      voice = "Прямо";
    } else {
      return;
    }

    await _flutterTts?.speak(voice);
  }

  Future<void> _startListening() async {
    setState(() => _isListening = true);
    await _flutterTts?.stop();
    
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(duration: 50);
    }

    await _speechService.startListening(onResult: (text) {
      setState(() {
        _spokenText = text;
      });
      
      
      
      
      
    });
  }

  Future<void> _stopListening() async {
    await _speechService.stopListening();
    setState(() => _isListening = false);

    if (_spokenText.isNotEmpty) {
      _processVoiceCommand(_spokenText);
    } else {
      await _flutterTts?.speak("Я вас не услышал.");
    }
  }

  Future<void> _processVoiceCommand(String text) async {
    setState(() => _isListening = false);
    if (text.isEmpty) return;

    await _flutterTts?.speak("Ищу маршрут до $text");

    
    Position? startPos = await _locationService.getCurrentPosition();
    if (startPos == null) {
      await _flutterTts?.speak("Нет GPS сигнала.");
      return;
    }

    
    Location? endLoc = await _navigationService.getCoordinatesFromAddress(text);
    if (endLoc == null) {
      await _flutterTts?.speak("Адрес не найден.");
      return;
    }

    
    List<RouteStep> steps = await _navigationService.getRoute(startPos, endLoc);
    if (steps.isEmpty) {
      await _flutterTts?.speak("Не удалось построить маршрут.");
      return;
    }

    setState(() {
      _routeSteps = steps;
      _currentStepIndex = 0;
      _isNavigating = true;
      _navigationCommand = "Маршрут построен";
    });

    _playNextInstruction();
  }

  void _playNextInstruction() {
    if (_routeSteps.isEmpty || _currentStepIndex >= _routeSteps.length) {
      _flutterTts?.speak("Вы пришли!");
      setState(() => _isNavigating = false);
      return;
    }

    RouteStep step = _routeSteps[_currentStepIndex];
    String instruction =
        "Через ${step.distance.toInt()} метров ${step.instruction}"; 
    
    
    _flutterTts?.speak(instruction);
  }

  @override
  void dispose() {
    _flutterTts?.stop();
    _sonarTimer?.cancel();
    _audioFeedbackService.dispose();

    
    _ocrController?.dispose();

    
    _compassSubscription?.cancel();
    _firebaseSyncTimer?.cancel();
    _webrtcService.dispose();
    _firebaseSyncService.dispose();

    super.dispose();
  }

  Future<void> _manageCameraResources() async {
    
    if (_currentMode == VisionMode.navigation) {
      if (_ocrController != null) {
        try {
          
          await _ocrController!.dispose();
        } catch (e) {
          debugPrint("Error disposing camera: $e");
        }
        _ocrController = null;
      }
      if (mounted) setState(() => _isOcrCameraReady = false);
    } else {
      
      if (_ocrController == null) {
        _initializeOcrCamera();
      }
    }
  }

  Future<void> _activateCurrentMode() async {
    await Vibration.vibrate(duration: 100);
    debugPrint("Activating mode: $_currentMode");

    if (_currentMode == VisionMode.navigation) {
      _flutterTts?.speak("Определяю местоположение...");
      try {
        Position? pos = await _locationService.getCurrentPosition();
        if (pos != null) {
          String address = await _locationService.getAddressFromPosition(pos);
          _flutterTts?.speak("Вы находитесь: $address");
        } else {
          _flutterTts?.speak("Не удалось определить местоположение");
        }
      } catch (e) {
        _flutterTts?.speak("Ошибка GPS");
      }
    } else {
      
      if (_ocrController == null || !_ocrController!.value.isInitialized) {
        _flutterTts?.speak("Камера не готова");
        await _manageCameraResources();
        return;
      }

      _flutterTts?.speak("Снимаю...");
      try {
        final image = await _ocrController!.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);

        final text = await _ocrService.processImage(inputImage);

        if (_currentMode == VisionMode.currency) {
          String? currency = _ocrService.detectCurrency(text);
          if (currency != null) {
            _flutterTts?.speak("Купюра: $currency");
          } else {
            _flutterTts?.speak("Купюра не распознана.");
          }
        } else {
          if (text.trim().isNotEmpty) {
            _flutterTts?.speak(text);
          } else {
            _flutterTts?.speak("Текст не найден");
          }
        }
      } catch (e) {
        debugPrint("OCR Error: $e");
        _flutterTts?.speak("Ошибка распознавания");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GestureDetector(
        onTap: _activateCurrentMode,
        onLongPressStart: (_) => _startListening(),
        onLongPressEnd: (_) => _stopListening(),
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            _switchMode(1);
          } else if (details.primaryVelocity! > 0) {
            _switchMode(-1);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            
            Container(
              key: ValueKey('camera_${_isInVolunteerCall ? 'call' : 'nav'}'),
              child: _buildCameraView(),
            ),

            
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 150,
              child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                Colors.black.withOpacity(0.8),
                Colors.transparent
              ], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 200,
              child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.9)
              ], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            ),

            
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: GlassContainer(
                opacity: 0.15,
                blur: 15,
                borderRadius: BorderRadius.circular(30),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    
                    Row(
                      children: [
                        Icon(_getModeIcon(_currentMode),
                            color: AppTheme.primary, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          _modeToString(_currentMode).toUpperCase(),
                          style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    
                    Row(
                      children: [
                        if (_isInVolunteerCall)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _remoteVolunteerUid != null
                                  ? AppTheme.primary.withOpacity(0.2)
                                  : AppTheme.warning.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _remoteVolunteerUid != null
                                      ? AppTheme.primary
                                      : AppTheme.warning),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.support_agent,
                                    size: 16,
                                    color: _remoteVolunteerUid != null
                                        ? AppTheme.primary
                                        : AppTheme.warning),
                                const SizedBox(width: 4),
                                Text(
                                  _remoteVolunteerUid != null ? "ON" : "WAIT",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: _remoteVolunteerUid != null
                                          ? AppTheme.primary
                                          : AppTheme.warning,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            ),

            
            if (_currentMode == VisionMode.navigation)
              Positioned(
                top: 120,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildZoneIndicator(Icons.arrow_back, "left"),
                    _buildZoneIndicator(Icons.arrow_upward, "center"),
                    _buildZoneIndicator(Icons.arrow_forward, "right"),
                  ],
                ),
              ),

            
            Positioned(
              bottom: 140,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  if (_navigationCommand.isNotEmpty)
                    Text(
                      _navigationCommand,
                      textAlign: TextAlign.center,
                      style: AppTheme.displayLarge.copyWith(
                          color: _getCommandColor(),
                          shadows: [
                            Shadow(
                                color: _getCommandColor().withOpacity(0.6),
                                blurRadius: 15)
                          ]),
                    ),
                  const SizedBox(height: 8),
                  
                  if (_distanceInfo.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        _distanceInfo,
                        style: AppTheme.bodyLarge
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                    ),

                  if (_isListening)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Icon(Icons.mic, color: AppTheme.urgent, size: 40),
                    ),
                ],
              ),
            ),

            
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  
                  _buildGlassButton(
                    onTap: () => _flutterTts?.speak("Кнопка СОС. Удерживайте."),
                    onLongPress: _handleSOS,
                    icon: Icons.sos,
                    color: AppTheme.urgent,
                    label: "SOS",
                  ),

                  
                  GestureDetector(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.5), width: 2)),
                      child:
                          Icon(Icons.touch_app, color: Colors.white, size: 30),
                    ),
                  ),

                  
                  _buildGlassButton(
                    onTap: () =>
                        _flutterTts?.speak("Звонок волонтеру. Удерживайте."),
                    onLongPress: _handleCall,
                    icon: Icons.phone_in_talk,
                    color: AppTheme.primary,
                    label: "CALL",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneIndicator(IconData icon, String zone) {
    Obstacle? closest;
    for (var o in _obstacles) {
      if (o.zone == zone &&
          (closest == null || o.distance < closest.distance)) {
        closest = o;
      }
    }

    Color color = AppTheme.textSecondary.withOpacity(0.3); 
    double scale = 1.0;

    if (closest != null) {
      if (closest.distance < criticalDistanceMeters) {
        color = AppTheme.urgent;
        scale = 1.2;
      } else if (closest.distance < warningDistanceMeters) {
        color = AppTheme.warning;
      } else if (closest.distance < cautionDistanceMeters) {
        color = AppTheme.secondary;
      }
    }

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: color.withOpacity(0.1), 
        border: Border.all(color: color.withOpacity(0.5)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  IconData _getModeIcon(VisionMode mode) {
    switch (mode) {
      case VisionMode.navigation:
        return Icons.explore;
      case VisionMode.text:
        return Icons.text_fields;
      case VisionMode.currency:
        return Icons.attach_money;
    }
  }

  void _switchMode(int delta) {
    
    int newIndex =
        (_currentMode.index + delta).clamp(0, VisionMode.values.length - 1);
    if (newIndex != _currentMode.index) {
      setState(() {
        _currentMode = VisionMode.values[newIndex];
      });
      _manageCameraResources();
      String modeName = _modeToString(_currentMode);
      _flutterTts?.speak("Режим: $modeName");
    }
  }

  String _modeToString(VisionMode mode) {
    switch (mode) {
      case VisionMode.navigation:
        return "Навигация";
      case VisionMode.text:
        return "Чтение текста";
      case VisionMode.currency:
        return "Чтение денег";
    }
  }

  Future<void> _initializeOcrCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _ocrController = CameraController(cameras.first, ResolutionPreset.high,
        enableAudio: false);
    try {
      await _ocrController!.initialize();
      setState(() => _isOcrCameraReady = true);

      
      
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  
  

  Widget _buildCameraView() {
    
    if (_isInVolunteerCall) {
      if (_webrtcService.engine != null) {
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _webrtcService.engine!,
            canvas: const VideoCanvas(uid: 0), 
          ),
        );
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    }

    if (_currentMode == VisionMode.navigation) {
      return YOLOView(
        key: const ValueKey(
            'yolo_navigation'), 
        modelPath: 'yolo11n',
        task: YOLOTask.detect,
        confidenceThreshold: 0.4,
        iouThreshold: 0.5,
        showOverlays: true,
        overlayTheme: const YOLOOverlayTheme(),
        onResult: _onYOLOResult,
        lensFacing: LensFacing.back,
      );
    } else {
      if (!_isOcrCameraReady || _ocrController == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return CameraPreview(_ocrController!);
    }
  }

  void _handleSOS() async {
    await Vibration.vibrate(duration: 500);
    _flutterTts?.speak("Отправляю СОС сообщение с вашими координатами.");

    List<String> recipients = ["112"];
    await _sosService.sendSOS(recipients);
  }

  void _handleCall() async {
    await Vibration.vibrate(duration: 100);
    _flutterTts?.speak("Соединяю с волонтером.");
    await _callVolunteer();
  }

  Future<void> _callVolunteer() async {
    if (_isInVolunteerCall) {
      await _endVolunteerCall();
      return;
    }

    try {
      
      if (_ocrController != null) {
        await _ocrController!.dispose(); 
        _ocrController = null;
      }

      setState(() {
        _isInVolunteerCall = true;
        
        
      });

      
      await Future.delayed(const Duration(milliseconds: 1500));

      String channelName = "test1";
      int uid = DateTime.now().millisecondsSinceEpoch % 100000;

      await _firebaseSyncService.updateStatus("in_call",
          channelName: channelName);
      await _webrtcService.joinChannel(channelName, uid);

      _flutterTts?.speak("Ожидаю подключения волонтера");
      _startFirebaseSync();
    } catch (e) {
      debugPrint("Error calling volunteer: $e");
      _flutterTts?.speak(" Ошибка соединения");
      setState(() {
        _isInVolunteerCall = false;
      });
    }
  }

  Future<void> _endVolunteerCall() async {
    try {
      await _webrtcService.leaveChannel();
      await _firebaseSyncService.updateStatus("active");
      _stopFirebaseSync();

      setState(() {
        _isInVolunteerCall = false;
        _remoteVolunteerUid = null;
      });

      _flutterTts?.speak("Звонок завершен");
    } catch (e) {
      debugPrint("Error ending call: $e");
    }
  }

  Timer? _firebaseSyncTimer;

  void _startFirebaseSync() {
    _firebaseSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isInVolunteerCall && _obstacles.isNotEmpty) {
        _syncToFirebase(_obstacles);
      }
    });
  }

  void _stopFirebaseSync() {
    _firebaseSyncTimer?.cancel();
    _firebaseSyncTimer = null;
  }

  Color _getCommandColor() {
    if (_navigationCommand.contains("СТОЙ")) return AppTheme.urgent;
    if (_navigationCommand.contains("ВЛЕВО") ||
        _navigationCommand.contains("ВПРАВО")) {
      return AppTheme.warning;
    }
    return AppTheme.primary;
  }
}
