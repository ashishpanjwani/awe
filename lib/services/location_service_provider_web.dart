// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:wanderwell/services/location_types.dart';

/// Web implementation using the browser Geolocation API directly to avoid
/// MissingPluginException in Flutter Web preview environments.
class LocationServiceProvider {
  Future<({double lat, double lon})?> getCurrentPosition() async {
    try {
      final geolocation = html.window.navigator.geolocation;
      if (geolocation == null) {
        debugPrint('[LocationService] Geolocation API not available in this browser');
        return null;
      }

      final completer = Completer<({double lat, double lon})?>();
      geolocation.getCurrentPosition(
        enableHighAccuracy: true,
        timeout: const Duration(seconds: 15),
        maximumAge: const Duration(seconds: 0),
      ).then((pos) {
        final coords = pos.coords;
        if (coords == null) {
          completer.complete(null);
          return;
        }
        final lat = (coords.latitude ?? 0).toDouble();
        final lon = (coords.longitude ?? 0).toDouble();
        completer.complete((lat: lat, lon: lon));
        }).catchError((error) {
          // Decode common browser geolocation errors for better diagnostics
          if (error is html.PositionError) {
            // error.code values: 1=PERMISSION_DENIED, 2=POSITION_UNAVAILABLE, 3=TIMEOUT
            final code = error.code;
            final msg = error.message ?? '';
            String reason;
            switch (code) {
              case 1:
                reason = 'PERMISSION_DENIED: User blocked or iframe/site not allowed';
                break;
              case 2:
                reason = 'POSITION_UNAVAILABLE: No signal or provider unavailable';
                break;
              case 3:
                reason = 'TIMEOUT: Operation took too long';
                break;
              default:
                reason = 'UNKNOWN';
            }
            debugPrint('[LocationService] Web geolocation error ($reason, code=$code): $msg');
          } else {
            debugPrint('[LocationService] Web geolocation error: ${error.runtimeType} $error');
          }
          completer.complete(null);
      });
      return completer.future;
    } catch (e, st) {
      debugPrint('[LocationService] Web geolocation exception: $e');
      debugPrint('$st');
      return null;
    }
  }

  // Web stubs: browser permissions cannot be opened programmatically.
  Future<bool> isLocationServiceEnabled() async {
    try {
      // If geolocation API is present, consider service enabled
      return html.window.navigator.geolocation != null;
    } catch (_) {
      return false;
    }
  }

  Future<AppLocationPermission> getPermissionStatus({bool requestIfDenied = false}) async {
    // Browser flows are handled by calling getCurrentPosition; here we return unknown.
    return AppLocationPermission.unknown;
  }

  Future<bool> openAppSettings() async {
    debugPrint('[LocationService] Web: openAppSettings not supported.');
    return false;
  }

  Future<bool> openLocationSettings() async {
    debugPrint('[LocationService] Web: openLocationSettings not supported.');
    return false;
  }
}
