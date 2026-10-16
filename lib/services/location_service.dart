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
  // Google Geocoding API key, passed at build/run time so it isn't committed:
  //   flutter run -d chrome --dart-define-from-file=env.json
  // where env.json (gitignored) is {"GOOGLE_GEOCODING_API_KEY": "..."}.
  static const _googleGeocodingKey =
      String.fromEnvironment('GOOGLE_GEOCODING_API_KEY');

  static Future<Map<String, double>?> geocodeAddress(String address) async {
    if (_googleGeocodingKey.isEmpty) {
      print('Google geocoding skipped: GOOGLE_GEOCODING_API_KEY not set '
          '(run with --dart-define-from-file=env.json)');
    } else {
      try {
        final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json',
            {'address': address, 'key': _googleGeocodingKey});
        final response = await http.get(uri);
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'OK') {
          final location =
              data['results'][0]['geometry']['location'] as Map<String, dynamic>;
          return {
            'lat': (location['lat'] as num).toDouble(),
            'lng': (location['lng'] as num).toDouble(),
          };
        }
        print('Google geocoding failed: status=${data['status']} '
            'error=${data['error_message'] ?? '(none)'}');
      } catch (e) {
        print('Google geocoding failed: $e');
      }
    }
    return _geocodeWithOpenStreetMap(address);
  }

  // ── OpenStreetMap (Nominatim) fallback ────────────────────────────────────
  // Free, no API key. Usage policy: max 1 request/second and the app must
  // identify itself (User-Agent on mobile/desktop; browsers don't allow
  // setting it, so we also send an `email` param when NOMINATIM_EMAIL is set
  // in env.json).
  //
  // Nominatim often can't match addresses with suite/unit numbers, so we try
  // several versions in order and stop at the first match:
  //   1. the address as typed
  //   2. unit info removed ("Ste 3", "Apt 4B", "#12", ...)
  //   3. structured search (street / city / state / postalcode, US only)
  //   4. city + state + zip only — returned with 'approximate': 1.0
  // The caller keeps saving the original typed address; these versions are
  // only used for the lookup.

  static const _nominatimEmail = String.fromEnvironment('NOMINATIM_EMAIL');

  // Each request waits for the previous one + 1.1 s, even if several
  // lookups run at once.
  static Future<void> _nominatimSlot = Future.value();
  static Future<void> _reserveNominatimSlot() {
    final previous = _nominatimSlot;
    _nominatimSlot = previous
        .then((_) => Future<void>.delayed(const Duration(milliseconds: 1100)));
    return previous;
  }

  static Future<Map<String, double>?> _geocodeWithOpenStreetMap(
      String address) async {
    final cleaned = _stripUnitInfo(address);
    final parts = _parseUsAddress(cleaned);

    final attempts = <(String, Map<String, String>, bool)>[
      ('1 (full address)', {'q': address}, false),
      if (cleaned != address) ('2 (unit info removed)', {'q': cleaned}, false),
      if (parts.street != null && (parts.city != null || parts.zip != null))
        (
          '3 (structured search)',
          {
            'street': parts.street!,
            if (parts.city != null) 'city': parts.city!,
            if (parts.state != null) 'state': parts.state!,
            if (parts.zip != null) 'postalcode': parts.zip!,
            'countrycodes': 'us',
          },
          false,
        ),
      if (parts.zip != null || (parts.city != null && parts.state != null))
        (
          '4 (city/state/zip only — approximate)',
          {
            if (parts.city != null) 'city': parts.city!,
            if (parts.state != null) 'state': parts.state!,
            if (parts.zip != null) 'postalcode': parts.zip!,
            'countrycodes': 'us',
          },
          true,
        ),
    ];

    for (final (label, params, approximate) in attempts) {
      try {
        await _reserveNominatimSlot();
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          ...params,
          'format': 'json',
          'limit': '1',
          if (_nominatimEmail.isNotEmpty) 'email': _nominatimEmail,
        });
        final response = await http.get(uri,
            headers: kIsWeb
                ? null
                : {'User-Agent': 'congressional_app (food rescue app)'});
        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isEmpty) {
          print('OpenStreetMap attempt $label: no match for $params');
          continue;
        }
        final first = results.first as Map<String, dynamic>;
        print('OpenStreetMap attempt $label matched: ${first['display_name']}');
        return {
          'lat': double.parse(first['lat'] as String),
          'lng': double.parse(first['lon'] as String),
          if (approximate) 'approximate': 1.0,
        };
      } catch (e) {
        print('OpenStreetMap attempt $label failed: $e');
      }
    }
    print('OpenStreetMap geocoding failed: no match for "$address"');
    return null;
  }

  static final _zipRe = RegExp(r'^\d{5}(-\d{4})?$');
  static final _stateRe = RegExp(r'^[A-Za-z]{2}$');
  static final _stateZipRe = RegExp(r'^[A-Za-z]{2}\s+\d{5}(-\d{4})?$');
  static final _unitRe = RegExp(
    r'(\b(ste|suite|apt|apartment|unit|bldg|fl|floor|rm)\b\.?\s*#?|#)\s*[a-z0-9-]+',
    caseSensitive: false,
  );

  // "317 NW Gilman Blvd Ste 3, Issaquah, WA, 98027"
  //   -> "317 NW Gilman Blvd, Issaquah, WA 98027"
  static String _stripUnitInfo(String address) {
    final segments = address.split(',').map((s) => s.trim()).toList();
    final out = <String>[];
    for (final seg in segments) {
      // Don't touch state/zip segments (so "FL 33101" isn't read as a floor).
      final isStateOrZip = _stateRe.hasMatch(seg) ||
          _zipRe.hasMatch(seg) ||
          _stateZipRe.hasMatch(seg);
      final s = (isStateOrZip ? seg : seg.replaceAll(_unitRe, ''))
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (s.isEmpty) continue;
      // Merge "WA", "98027" -> "WA 98027"
      if (_zipRe.hasMatch(s) && out.isNotEmpty && _stateRe.hasMatch(out.last)) {
        out[out.length - 1] = '${out.last} $s';
      } else {
        out.add(s);
      }
    }
    return out.join(', ');
  }

  // Best-effort split of a cleaned US address into street/city/state/zip.
  static ({String? street, String? city, String? state, String? zip})
      _parseUsAddress(String cleaned) {
    final segs = cleaned
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .where((s) => !RegExp(r'^(usa?|united states( of america)?)$',
                caseSensitive: false)
            .hasMatch(s))
        .toList();
    if (segs.isEmpty) return (street: null, city: null, state: null, zip: null);

    String? city, state, zip;
    if (segs.length > 1 && _zipRe.hasMatch(segs.last)) zip = segs.removeLast();

    if (segs.length > 1) {
      // Last segment: "WA", "WA 98027", or "Issaquah WA 98027"
      final m = RegExp(r'^(?:(.*?)\s+)?([A-Za-z]{2})(?:\s+(\d{5}(?:-\d{4})?))?$')
          .firstMatch(segs.last);
      if (m != null) {
        state = m.group(2)!.toUpperCase();
        zip ??= m.group(3);
        final inlineCity = m.group(1);
        segs.removeLast();
        if (inlineCity != null && inlineCity.isNotEmpty) {
          city = inlineCity;
        } else if (segs.length > 1) {
          city = segs.removeLast();
        }
      } else if (segs.length > 1) {
        city = segs.removeLast();
      }
    }
    return (street: segs.first, city: city, state: state, zip: zip);
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
