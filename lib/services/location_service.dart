import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Use conditional provider to avoid MissingPluginException on web.
// On mobile (Android/iOS), we use Geolocator. On Web, we use browser Geolocation API.
import 'package:wanderwell/services/location_service_provider_mobile.dart'
    if (dart.library.html) 'package:wanderwell/services/location_service_provider_web.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final LocationServiceProvider _provider = LocationServiceProvider();

  Future<({double lat, double lon, String name})?> getCurrentLocationWithName() async {
    try {
      final pos = await _provider.getCurrentPosition();
      if (pos != null) {
        final name = await _reverseGeocode(pos.lat, pos.lon);
        return (lat: pos.lat, lon: pos.lon, name: name);
      }

      // Fallback: approximate by IP if precise geolocation is unavailable/denied (Web safe)
      final ipPos = await _ipGeolocate();
      if (ipPos != null) {
        debugPrint('[LocationService] Using approximate IP-based location: ${ipPos.name}');
        return ipPos;
      }
      return null;
    } catch (e, st) {
      debugPrint('[LocationService] getCurrentLocationWithName error: $e');
      debugPrint('$st');
      return null;
    }
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
    // Use Nominatim (OpenStreetMap) reverse geocoding, no API key required.
    // Respect rate limits and include a descriptive User-Agent via headers.
    final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=10&addressdetails=1');
    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'wanderwell-app/1.0 (https://example.com)'
      });
      if (res.statusCode != 200) {
        debugPrint('[LocationService] Nominatim HTTP ${res.statusCode}');
        return 'Current Location';
      }
      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final addr = (data['address'] ?? {}) as Map<String, dynamic>;
      final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['hamlet'] ?? '') as String;
      final state = (addr['state'] ?? '') as String;
      final countryCode = (addr['country_code'] ?? '') as String; // lowercased
      final parts = [
        if (city.isNotEmpty) city,
        if (countryCode.isNotEmpty) countryCode.toUpperCase(),
        if (city.isEmpty && state.isNotEmpty) state,
      ];
      return parts.isEmpty ? 'Current Location' : parts.join(', ');
    } catch (e, st) {
      debugPrint('[LocationService] reverse geocode error: $e');
      debugPrint('$st');
      return 'Current Location';
    }
  }

  /// Lightweight IP-based geolocation fallback (city-level). No API key.
  /// Returns null if the service fails.
  Future<({double lat, double lon, String name})?> _ipGeolocate() async {
    // Try ipapi.co first, then fall back to ipinfo.io. Add timeouts and
    // keep errors quiet to avoid noisy logs in restricted environments.
    try {
      final uri = Uri.parse('https://ipapi.co/json/');
      final res = await http
          .get(uri, headers: {
            'User-Agent': 'wanderwell-app/1.0 (https://example.com)'
          })
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final city = (data['city'] ?? '') as String;
        final country = (data['country_code'] ?? '') as String;
        final lat = (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : null;
        final lon = (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : null;
        if (lat != null && lon != null) {
          final labelParts = [if (city.isNotEmpty) city, if (country.isNotEmpty) country];
          final name = labelParts.isEmpty ? 'Your Area' : labelParts.join(', ');
          return (lat: lat, lon: lon, name: name);
        }
      }
    } catch (e) {
      debugPrint('[LocationService] IP geolocation error (ipapi): $e');
    }

    // Fallback to ipinfo.io (no token, approximate). Example payload:
    // { city: "", country: "US", loc: "37.3860,-122.0838" }
    try {
      final uri = Uri.parse('https://ipinfo.io/json');
      final res = await http
          .get(uri, headers: {
            'User-Agent': 'wanderwell-app/1.0 (https://example.com)'
          })
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final city = (data['city'] ?? '') as String;
      final country = (data['country'] ?? '') as String; // already uppercased usually
      final loc = (data['loc'] ?? '') as String; // "lat,lon"
      final parts = loc.split(',');
      if (parts.length != 2) return null;
      final lat = double.tryParse(parts[0]);
      final lon = double.tryParse(parts[1]);
      if (lat == null || lon == null) return null;
      final labelParts = [if (city.isNotEmpty) city, if (country.isNotEmpty) country];
      final name = labelParts.isEmpty ? 'Your Area' : labelParts.join(', ');
      return (lat: lat, lon: lon, name: name);
    } catch (e) {
      debugPrint('[LocationService] IP geolocation error (ipinfo): $e');
      return null;
    }
  }
}
