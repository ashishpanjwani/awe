import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FoursquareVenue {
  final String id;
  final String name;
  final String category;
  final String? address;
  final String? neighborhood;
  final double? lat;
  final double? lon;
  final double? rating;
  final String? url;
  final String? photoUrl;

  const FoursquareVenue({
    required this.id,
    required this.name,
    required this.category,
    this.address,
    this.neighborhood,
    this.lat,
    this.lon,
    this.rating,
    this.url,
    this.photoUrl,
  });

  String get mapsUrl => 'https://www.google.com/maps/search/${Uri.encodeComponent('$name ${neighborhood ?? address ?? ''}')}';
  String get foursquareUrl => 'https://foursquare.com/v/$id';
}

class FoursquareService {
  FoursquareService._();
  static final FoursquareService _instance = FoursquareService._();
  factory FoursquareService() => _instance;

  String get _apiKey => dotenv.env['FOURSQUARE_API_KEY'] ?? '';
  bool get hasKey => _apiKey.isNotEmpty;

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.foursquare.com/v3',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Options get _authOptions => Options(
        headers: {
          'Authorization': _apiKey,
          'Accept': 'application/json',
        },
      );

  /// Search for places near a location
  Future<List<FoursquareVenue>> searchPlaces({
    required String query,
    required String near,
    int limit = 5,
  }) async {
    if (!hasKey) return [];
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/places/search',
        queryParameters: {
          'query': query,
          'near': near,
          'limit': limit,
          'fields': 'fsq_id,name,categories,location,rating,link,photos',
        },
        options: _authOptions,
      );
      return _parseResults(resp.data);
    } on DioException catch (e) {
      debugPrint('[Foursquare] searchPlaces error: ${e.message}');
      return [];
    }
  }

  /// Get top-rated restaurants
  Future<List<FoursquareVenue>> topFood({
    required String near,
    int limit = 5,
  }) async {
    if (!hasKey) return [];
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/places/search',
        queryParameters: {
          'near': near,
          'categories': '13065', // restaurants
          'sort': 'RATING',
          'limit': limit,
          'fields': 'fsq_id,name,categories,location,rating,link,photos',
        },
        options: _authOptions,
      );
      return _parseResults(resp.data);
    } on DioException catch (e) {
      debugPrint('[Foursquare] topFood error: ${e.message}');
      return [];
    }
  }

  /// Get popular attractions and landmarks
  Future<List<FoursquareVenue>> topAttractions({
    required String near,
    int limit = 5,
  }) async {
    if (!hasKey) return [];
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/places/search',
        queryParameters: {
          'near': near,
          'categories': '16000', // landmarks and outdoors
          'sort': 'RATING',
          'limit': limit,
          'fields': 'fsq_id,name,categories,location,rating,link,photos',
        },
        options: _authOptions,
      );
      return _parseResults(resp.data);
    } on DioException catch (e) {
      debugPrint('[Foursquare] topAttractions error: ${e.message}');
      return [];
    }
  }

  /// Get trending venues (actual real-time trending)
  Future<List<FoursquareVenue>> trending({
    required double lat,
    required double lon,
    int limit = 5,
  }) async {
    if (!hasKey) return [];
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/places/nearby',
        queryParameters: {
          'll': '$lat,$lon',
          'limit': limit,
          'fields': 'fsq_id,name,categories,location,rating,link,photos',
        },
        options: _authOptions,
      );
      return _parseResults(resp.data);
    } on DioException catch (e) {
      debugPrint('[Foursquare] trending error: ${e.message}');
      return [];
    }
  }

  /// Fetch all quest data for a city in parallel
  Future<FoursquareQuestData> fetchAllForCity(String city, {double? lat, double? lon}) async {
    if (!hasKey) {
      debugPrint('[Foursquare] No API key — skipping');
      return FoursquareQuestData.empty();
    }

    final results = await Future.wait([
      topFood(near: city, limit: 5),
      topAttractions(near: city, limit: 5),
      searchPlaces(query: 'things to do', near: city, limit: 5),
      if (lat != null && lon != null)
        trending(lat: lat, lon: lon, limit: 5)
      else
        Future.value(<FoursquareVenue>[]),
    ]);

    debugPrint('[Foursquare] Fetched for "$city": '
        '${results[0].length} food, ${results[1].length} attractions, '
        '${results[2].length} experiences, ${results[3].length} trending');

    return FoursquareQuestData(
      food: results[0],
      attractions: results[1],
      experiences: results[2],
      trending: results[3],
    );
  }

  List<FoursquareVenue> _parseResults(Map<String, dynamic>? data) {
    final results = (data?['results'] as List?) ?? [];
    return results.map((r) {
      final loc = r['location'] as Map<String, dynamic>? ?? {};
      final cats = (r['categories'] as List?) ?? [];
      final catName = cats.isNotEmpty
          ? (cats.first['short_name'] as String? ?? cats.first['name'] as String? ?? 'Place')
          : 'Place';

      String? photoUrl;
      final photos = (r['photos'] as List?) ?? [];
      if (photos.isNotEmpty) {
        final p = photos.first;
        photoUrl = '${p['prefix']}300x300${p['suffix']}';
      }

      return FoursquareVenue(
        id: (r['fsq_id'] as String?) ?? '',
        name: (r['name'] as String?) ?? '',
        category: catName,
        address: loc['formatted_address'] as String?,
        neighborhood: loc['neighborhood'] as String? ??
            loc['locality'] as String?,
        lat: (loc['latitude'] as num?)?.toDouble(),
        lon: (loc['longitude'] as num?)?.toDouble(),
        rating: (r['rating'] as num?)?.toDouble(),
        url: r['link'] as String?,
        photoUrl: photoUrl,
      );
    }).where((v) => v.name.isNotEmpty).toList();
  }
}

class FoursquareQuestData {
  final List<FoursquareVenue> food;
  final List<FoursquareVenue> attractions;
  final List<FoursquareVenue> experiences;
  final List<FoursquareVenue> trending;

  const FoursquareQuestData({
    required this.food,
    required this.attractions,
    required this.experiences,
    required this.trending,
  });

  factory FoursquareQuestData.empty() => const FoursquareQuestData(
        food: [],
        attractions: [],
        experiences: [],
        trending: [],
      );

  bool get isEmpty => food.isEmpty && attractions.isEmpty && experiences.isEmpty && trending.isEmpty;
  int get totalCount => food.length + attractions.length + experiences.length + trending.length;
}
