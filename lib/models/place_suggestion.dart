import 'dart:convert';

/// Lightweight model for place suggestions returned by Photon (OpenStreetMap).
/// Designed for autocomplete: contains display label and geo coordinates.
class PlaceSuggestion {
  final String label; // e.g., "Paris, Île-de-France, France"
  final String? name; // primary name (city/state/country)
  final String? city;
  final String? state;
  final String? country;
  final double lat;
  final double lon;
  final String? osmValue; // e.g., city, town, village, state, country

  const PlaceSuggestion({
    required this.label,
    required this.lat,
    required this.lon,
    this.name,
    this.city,
    this.state,
    this.country,
    this.osmValue,
  });

  factory PlaceSuggestion.fromPhotonFeature(Map<String, dynamic> feature) {
    final props = (feature['properties'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final geom = (feature['geometry'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final coords = (geom['coordinates'] as List?)?.cast<num>() ?? const <num>[];

    final primary = (props['name'] ?? props['city'] ?? props['state'] ?? props['country'] ?? '').toString();
    final city = (props['city'] ?? props['town'] ?? props['village'] ?? props['suburb'])?.toString();
    final state = (props['state'] ?? props['region'] ?? props['county'])?.toString();
    final country = props['country']?.toString();
    final parts = <String>[
      if (primary.isNotEmpty) primary,
      if (state != null && state.isNotEmpty && state != primary) state,
      if (country != null && country.isNotEmpty && country != primary) country,
    ];
    final label = parts.join(', ');
    final lat = coords.length >= 2 ? coords[1].toDouble() : 0.0;
    final lon = coords.length >= 2 ? coords[0].toDouble() : 0.0;
    final osmValue = props['osm_value']?.toString();

    return PlaceSuggestion(
      label: label.isEmpty ? jsonEncode(props) : label,
      name: primary.isEmpty ? null : primary,
      city: city,
      state: state,
      country: country,
      lat: lat,
      lon: lon,
      osmValue: osmValue,
    );
  }
}
