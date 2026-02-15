import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class SOSService {
  Future<void> sendSOS(List<String> recipients) async {
    try {
      
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      String mapLink =
          "https://maps.google.com/?q=${position.latitude},${position.longitude}";
      String message =
          "SOS! Я использую NaviBlind и мне нужна помощь. Моя геопозиция: $mapLink";

      
      final String smsUri =
          'sms:${recipients.join(',')}?body=${Uri.encodeComponent(message)}';

      if (await canLaunchUrl(Uri.parse(smsUri))) {
        await launchUrl(Uri.parse(smsUri));
      } else {
        debugPrint("Could not launch SMS");
      }
    } catch (e) {
      debugPrint("SOS Failed: $e");
    }
  }

  Future<void> callVolunteer(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint("Could not launch $launchUri");
    }
  }
}
