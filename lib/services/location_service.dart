import 'dart:convert';
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

  static Future<Map<String, double>?> geocodeAddress(String address) async {
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
    return null;
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
