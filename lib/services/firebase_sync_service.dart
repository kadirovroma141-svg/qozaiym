import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../vision_page.dart'; 

class FirebaseSyncService {
  DatabaseReference? _database;
  String? _sessionId;

  FirebaseSyncService() {
    try {
      _database = FirebaseDatabase.instance.ref();
    } catch (e) {
      debugPrint("FirebaseSyncService init error: $e");
    }
  }

  void setUserId(String userId) {
    _sessionId = "session_$userId";
  }

  
  Future<void> syncLocation(Position position, double heading) async {
    if (_sessionId == null) return;

    if (_database == null) return;

    try {
      await _database!.child('sessions/$_sessionId/location').set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': heading,
        'accuracy': position.accuracy,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint("Firebase sync location error: $e");
    }
  }

  
  Future<void> syncYOLOData(List<Obstacle> obstacles) async {
    if (_sessionId == null) return;

    try {
      List<Map<String, dynamic>> obstacleData = obstacles.map((o) {
        return {
          'label': o.label,
          'confidence': o.confidence,
          'box': {
            'left': o.box.left,
            'top': o.box.top,
            'width': o.box.width,
            'height': o.box.height,
          },
          'distance': o.distance,
          'zone': o.zone,
        };
      }).toList();

      if (_database == null) return;

      await _database!.child('sessions/$_sessionId/yolo').set({
        'obstacles': obstacleData,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint("Firebase sync YOLO error: $e");
    }
  }

  
  Future<void> syncNavigationCommand(String command, String mode) async {
    if (_sessionId == null) return;

    try {
      if (_database == null) return;

      await _database!.child('sessions/$_sessionId/navigation').set({
        'command': command,
        'mode': mode,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint("Firebase sync navigation error: $e");
    }
  }

  
  Future<void> updateStatus(String status, {String? channelName}) async {
    if (_sessionId == null) return;

    try {
      Map<String, dynamic> data = {
        'status': status,
        'timestamp': ServerValue.timestamp,
      };

      if (channelName != null) {
        data['channel_name'] = channelName;
      }

      if (_database == null) return;

      await _database!.child('sessions/$_sessionId').update(data);
    } catch (e) {
      debugPrint("Firebase update status error: $e");
    }
  }

  
  Stream<bool> listenVolunteerJoined() {
    if (_sessionId == null) {
      return Stream.value(false);
    }

    if (_database == null) return Stream.value(false);

    return _database!
        .child('sessions/$_sessionId/volunteer_joined')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return false;
      return event.snapshot.value as bool;
    });
  }

  
  Future<void> clearSession() async {
    if (_sessionId == null) return;

    try {
      if (_database == null) return;

      await _database!.child('sessions/$_sessionId').remove();
    } catch (e) {
      debugPrint("Firebase clear session error: $e");
    }
  }

  void dispose() {
    
  }
}
