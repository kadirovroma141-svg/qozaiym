import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart'; 

class RouteStep {
  final String instruction;
  final double distance; 
  final int duration; 
  final Map<String, dynamic> maneuver;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.maneuver,
  });
}

class NavigationService {
  final String _osrmBaseUrl = 'http://router.project-osrm.org/route/v1/foot';

  
  Future<Location?> getCoordinatesFromAddress(String address) async {
    try {
      
      final encodedAddress = Uri.encodeComponent(address);
      final url =
          'https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&addressdetails=1&limit=1&accept-language=ru';

      debugPrint("Geocoding: Searching for address: $address");
      debugPrint("Geocoding: URL: $url");

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'NaviBlind/1.0', 
        },
      );

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        debugPrint("Geocoding: Got ${results.length} results");

        if (results.isNotEmpty) {
          final result = results[0];
          final lat = double.parse(result['lat']);
          final lon = double.parse(result['lon']);
          debugPrint("Geocoding: Found coordinates: $lat, $lon");
          debugPrint("Geocoding: Display name: ${result['display_name']}");

          
          return Location(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.now(),
          );
        } else {
          debugPrint("Geocoding: No results found for address");
        }
      } else {
        debugPrint("Geocoding: HTTP error ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
    return null;
  }

  
  Future<List<RouteStep>> getRoute(Position start, Location end) async {
    final String url =
        '$_osrmBaseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?steps=true&geometries=geojson&overview=false&languages=ru';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final legs = data['routes'][0]['legs'][0];
          final steps = legs['steps'] as List;

          return steps.map((step) {
            return RouteStep(
              instruction:
                  "${step['maneuver']['type']} ${step['maneuver']['modifier'] ?? ''}",
              distance: (step['distance'] as num).toDouble(),
              duration: (step['duration'] as num).toInt(),
              maneuver: step['maneuver'],
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("OSRM error: $e");
    }
    return [];
  }
}
