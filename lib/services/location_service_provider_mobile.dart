import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Mobile (Android/iOS) implementation using Geolocator.
class LocationServiceProvider {
  Future<({double lat, double lon})?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permission not granted: $permission');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return (lat: pos.latitude, lon: pos.longitude);
    } catch (e, st) {
      debugPrint('[LocationService] Mobile geolocation error: $e');
      debugPrint('$st');
      return null;
    }
  }
}
