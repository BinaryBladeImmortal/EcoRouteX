import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapService {
  // Convert place name → coordinates (Photon API)
  static Future<LatLng?> getCoordinates(String place) async {
    if (place.trim().isEmpty) return null;
    
    final url =
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(place)}&limit=1';

    try {
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        if (data['features'] != null && data['features'].isNotEmpty) {
          final coords = data['features'][0]['geometry']['coordinates'];
          return LatLng(coords[1], coords[0]); // lat, lng
        }
      }
    } catch (e) {
      print('Photon API error: $e');
    }
    return null;
  }

  // Get route polyline between two points (OSRM API)
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'];
          return coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
        }
      }
    } catch (e) {
      print('OSRM API error: $e');
    }

    return [];
  }

  // Calculate distance between two points in km (OSRM)
  static Future<double?> getDistance(LatLng start, LatLng end) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=false';

    try {
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final meters = data['routes'][0]['distance'] as num;
          return meters / 1000; // Convert to km
        }
      }
    } catch (e) {
      print('OSRM distance error: $e');
    }

    return null;
  }
}
