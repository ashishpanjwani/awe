import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wanderwell/services/location_types.dart';

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

  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('[LocationService] isLocationServiceEnabled error: $e');
      return false;
    }
  }

  Future<AppLocationPermission> getPermissionStatus({bool requestIfDenied = false}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestIfDenied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return AppLocationPermission.granted;
        case LocationPermission.denied:
          return AppLocationPermission.denied;
        case LocationPermission.deniedForever:
          return AppLocationPermission.deniedForever;
        case LocationPermission.unableToDetermine:
          return AppLocationPermission.unknown;
      }
    } catch (e) {
      debugPrint('[LocationService] getPermissionStatus error: $e');
      return AppLocationPermission.unknown;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      final opened = await Geolocator.openAppSettings();
      return opened;
    } catch (e) {
      debugPrint('[LocationService] openAppSettings error: $e');
      return false;
    }
  }

  Future<bool> openLocationSettings() async {
    try {
      final opened = await Geolocator.openLocationSettings();
      return opened;
    } catch (e) {
      debugPrint('[LocationService] openLocationSettings error: $e');
      return false;
    }
  }
}
