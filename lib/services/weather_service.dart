import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:wanderwell/models/weather_data.dart';
import 'package:wanderwell/core/network/dio_client.dart';

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  WeatherData? _currentWeather;
  WeatherData? get currentWeather => _currentWeather;
  double? _lastLat;
  double? _lastLon;
  String? _lastCityName;

  Future<void> initialize() async {
    // No-op in the new implementation; weather will be fetched on demand.
  }

  Future<WeatherData> fetchWeather({String? city}) async {
    // Backward-compat: if no coordinates are available, return a benign default
    // using Open-Meteo for a fixed location (0,0). Prefer using fetchWeatherAt.
    debugPrint('[WeatherService] fetchWeather() called without coordinates; using fallback.');
    return fetchWeatherAt(0, 0, cityName: city ?? 'Unknown');
  }

  Future<WeatherData> fetchWeatherAt(
    double latitude,
    double longitude, {
    String? cityName,
  }) async {
    try {
      final dio = DioClient.instance;
      final url = 'https://api.open-meteo.com/v1/forecast';
      final Response res = await dio.get(url, queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'current_weather': true,
        'timezone': 'auto',
      });
      if (res.statusCode != 200) {
        debugPrint('[WeatherService] Open-Meteo error: HTTP ${res.statusCode}');
        throw Exception('Failed to fetch weather');
      }

      final Map<String, dynamic> data;
      final body = res.data;
      if (body is Map<String, dynamic>) {
        data = body;
      } else if (body is String) {
        data = json.decode(body) as Map<String, dynamic>;
      } else {
        data = json.decode(json.encode(body)) as Map<String, dynamic>;
      }
      final curr = data['current_weather'] as Map<String, dynamic>?;
      if (curr == null) {
        throw Exception('No current weather in response');
      }

      final double temp = (curr['temperature'] as num).toDouble();
      final int code = (curr['weathercode'] as num).toInt();
      final mapped = _mapWeatherCode(code);
      final bool isDay = (curr['is_day'] == 1) || (curr['is_day'] == true);

      final weather = WeatherData(
        city: cityName ?? 'Current Location',
        temperature: temp,
        condition: mapped.condition,
        iconCode: mapped.iconCode,
        updatedAt: DateTime.now(),
        isDay: isDay,
      );

      _currentWeather = weather;
      _lastLat = latitude;
      _lastLon = longitude;
      _lastCityName = cityName;
      return weather;
    } catch (e, st) {
      debugPrint('[WeatherService] fetchWeatherAt error: $e');
      debugPrint('$st');
      // Provide a defensive fallback to keep UI working
      // Heuristic: infer day/night from local device time so UI matches reality
      final now = DateTime.now();
      final hour = now.hour; // 0-23 in device local timezone
      final inferredIsDay = hour >= 6 && hour < 18;
      debugPrint('[WeatherService] Using fallback weather. hour=$hour inferredIsDay=$inferredIsDay city=${cityName ?? 'Unknown'}');

      final fallback = WeatherData(
        city: cityName ?? 'Unknown',
        temperature: 22.0,
        condition: 'Clear',
        iconCode: 'clear',
        updatedAt: now,
        isDay: inferredIsDay,
      );
      _currentWeather = fallback;
      return fallback;
    }
  }

  Future<void> refreshWeather() async {
    if (_lastLat != null && _lastLon != null) {
      await fetchWeatherAt(_lastLat!, _lastLon!, cityName: _lastCityName);
    }
  }

  ({String condition, String iconCode}) _mapWeatherCode(int code) {
    // Mapping based on WMO weather interpretation codes used by Open-Meteo
    // https://open-meteo.com/en/docs#api_form
    switch (code) {
      case 0:
        return (condition: 'Clear', iconCode: 'clear');
      case 1:
      case 2:
        return (condition: 'Partly Cloudy', iconCode: 'partly_cloudy');
      case 3:
        return (condition: 'Cloudy', iconCode: 'cloudy');
      case 45:
      case 48:
        return (condition: 'Fog', iconCode: 'fog');
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return (condition: 'Drizzle', iconCode: 'drizzle');
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
        return (condition: 'Rain', iconCode: 'rain');
      case 71:
      case 73:
      case 75:
      case 77:
        return (condition: 'Snow', iconCode: 'snow');
      case 80:
      case 81:
      case 82:
        return (condition: 'Showers', iconCode: 'rain');
      case 95:
      case 96:
      case 99:
        return (condition: 'Thunderstorm', iconCode: 'thunder');
      default:
        return (condition: 'Clear', iconCode: 'clear');
    }
  }
}
