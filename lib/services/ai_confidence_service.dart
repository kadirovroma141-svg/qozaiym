import 'package:flutter/material.dart'; 
import '../vision_page.dart'; 

class AIConfidenceService {
  
  bool shouldSuggestVolunteer(List<Obstacle> obstacles) {
    if (obstacles.isEmpty) return false;

    
    int lowConfidenceCount = obstacles
        .where((o) => o.confidence < 0.4 && o.confidence > 0.25)
        .length;

    if (lowConfidenceCount >= 3) {
      return true; 
    }

    
    bool hasCriticalUncertainty = obstacles.any(
        (o) => o.confidence < 0.5 && o.zone == "center" && o.distance < 3.0);

    if (hasCriticalUncertainty) {
      return true; 
    }

    
    if (_detectConflict(obstacles)) {
      return true; 
    }

    return false;
  }

  
  bool _detectConflict(List<Obstacle> obstacles) {
    for (int i = 0; i < obstacles.length; i++) {
      for (int j = i + 1; j < obstacles.length; j++) {
        
        double overlap = _calculateOverlap(obstacles[i].box, obstacles[j].box);

        
        if (overlap > 0.5 &&
            obstacles[i].label != obstacles[j].label &&
            (obstacles[i].confidence - obstacles[j].confidence).abs() < 0.2) {
          return true;
        }
      }
    }
    return false;
  }

  
  double _calculateOverlap(Rect box1, Rect box2) {
    double x1 = box1.left > box2.left ? box1.left : box2.left;
    double y1 = box1.top > box2.top ? box1.top : box2.top;
    double x2 = box1.right < box2.right ? box1.right : box2.right;
    double y2 = box1.bottom < box2.bottom ? box1.bottom : box2.bottom;

    if (x2 < x1 || y2 < y1) return 0.0;

    double intersection = (x2 - x1) * (y2 - y1);
    double area1 = box1.width * box1.height;
    double area2 = box2.width * box2.height;
    double union = area1 + area2 - intersection;

    return intersection / union;
  }

  
  String getExplanationMessage(List<Obstacle> obstacles) {
    int lowConfidenceCount = obstacles
        .where((o) => o.confidence < 0.4 && o.confidence > 0.25)
        .length;

    if (lowConfidenceCount >= 3) {
      return "Я вижу много неясных объектов впереди";
    }

    bool hasCriticalUncertainty = obstacles.any(
        (o) => o.confidence < 0.5 && o.zone == "center" && o.distance < 3.0);

    if (hasCriticalUncertainty) {
      return "Я не уверен, что впереди. Это может быть опасно";
    }

    if (_detectConflict(obstacles)) {
      return "Ситуация впереди мне непонятна";
    }

    return "Мне нужна помощь в понимании ситуации";
  }
}
