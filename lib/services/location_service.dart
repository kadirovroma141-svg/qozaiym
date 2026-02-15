import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_compass/flutter_compass.dart';

class LocationService {
  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      
      
      
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await _handlePermission();
    if (!hasPermission) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> getAddressFromPosition(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        
        List<String> parts = [];
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          parts.add(place.thoroughfare!);
        }
        if (place.subThoroughfare != null &&
            place.subThoroughfare!.isNotEmpty) {
          parts.add(place.subThoroughfare!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          parts.add(place.locality!);
        }

        return parts.join(", ");
      }
    } catch (e) {
      
    }
    return "Не удалось определить адрес";
  }

  Stream<CompassEvent>? getCompassStream() {
    return FlutterCompass.events;
  }
}
