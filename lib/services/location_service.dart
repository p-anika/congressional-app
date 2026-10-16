import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static double distanceInMiles(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    final meters = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    return meters / 1609.344;
  }

  // Tries Google first; if that fails (e.g. Geocoding API not enabled on the
  // key, or blocked by CORS on web), falls back to OpenStreetMap.
  static Future<Map<String, double>?> geocodeAddress(String address) async {
    try {
      const apiKey = 'AIzaSyD1ipEScnyIp9lNFSIC6nmxVPq6Fu0E2VI';
      final encoded = Uri.encodeComponent(address);
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encoded&key=$apiKey';
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      print('Geocoding response: ${response.body}');

      if (data['status'] == 'OK') {
        final location =
            data['results'][0]['geometry']['location'] as Map<String, dynamic>;
        return {
          'lat': (location['lat'] as num).toDouble(),
          'lng': (location['lng'] as num).toDouble(),
        };
      }
    } catch (e) {
      print('Google geocoding failed: $e');
    }
    return _geocodeWithOpenStreetMap(address);
  }

  // Free OpenStreetMap (Nominatim) geocoder — no API key needed. Usage
  // policy: max ~1 request/second and the app must identify itself.
  static Future<Map<String, double>?> _geocodeWithOpenStreetMap(
      String address) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': address,
        'format': 'json',
        'limit': '1',
      });
      // Browsers don't allow setting User-Agent; they send their own.
      final response = await http.get(uri,
          headers: kIsWeb
              ? null
              : {'User-Agent': 'congressional_app (food rescue app)'});
      final results = jsonDecode(response.body) as List<dynamic>;
      print('OpenStreetMap geocoding response: ${response.body}');
      if (results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      return {
        'lat': double.parse(first['lat'] as String),
        'lng': double.parse(first['lon'] as String),
      };
    } catch (e) {
      print('OpenStreetMap geocoding failed: $e');
      return null;
    }
  }

  static Uri buildGoogleMapsDirectionsUrl({
    double? originLat,
    double? originLng,
    required double destinationLat,
    required double destinationLng,
    String travelMode = 'driving',
  }) {
    final queryParameters = <String, String>{
      'api': '1',
      'destination': '$destinationLat,$destinationLng',
      'travelmode': travelMode,
    };

    if (originLat != null && originLng != null) {
      queryParameters['origin'] = '$originLat,$originLng';
    }

    return Uri.https('www.google.com', '/maps/dir/', queryParameters);
  }

  static Future<bool> launchGoogleMapsDirections({
    double? originLat,
    double? originLng,
    required double destinationLat,
    required double destinationLng,
    String travelMode = 'driving',
  }) async {
    final uri = buildGoogleMapsDirectionsUrl(
      originLat: originLat,
      originLng: originLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      travelMode: travelMode,
    );

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
