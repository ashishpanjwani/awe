import 'package:wanderwell/services/location_types.dart';

// Geolocator removed — quest/location feature is temporarily paused.
// To restore: re-add `geolocator: 13.0.4` to pubspec.yaml and replace
// these stubs with the original Geolocator-based implementations.

class LocationServiceProvider {
  Future<({double lat, double lon})?> getCurrentPosition() async => null;
  Future<bool> isLocationServiceEnabled() async => false;
  Future<AppLocationPermission> getPermissionStatus({bool requestIfDenied = false}) async => AppLocationPermission.unknown;
  Future<bool> openAppSettings() async => false;
  Future<bool> openLocationSettings() async => false;
}
