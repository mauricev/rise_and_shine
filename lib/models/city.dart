// lib/models/city.dart

class City {
  final String name;
  final String country;
  final String? state;
  final double latitude;
  final double longitude;
  final int timezoneOffsetSeconds;

  City({
    required this.name,
    required this.country,
    this.state,
    required this.latitude,
    required this.longitude,
    required this.timezoneOffsetSeconds,
  });

  // Factory constructor to create a City from JSON (e.g., from OpenWeatherMap Geocoding API or Hive)
  factory City.fromJson(Map<String, dynamic> json) {
    // FIX: Use Map<String, dynamic>.from for robustness if json is _Map<dynamic, dynamic>
    final Map<String, dynamic> safeJson = Map<String, dynamic>.from(json);
    return City(
      name: safeJson['name'] as String,
      country: safeJson['country'] as String,
      state: safeJson['state'] as String?,
      latitude: (safeJson['lat'] as num).toDouble(),
      longitude: (safeJson['lon'] as num).toDouble(),
      timezoneOffsetSeconds: safeJson['timezoneOffsetSeconds'] as int,
    );
  }

  // Method to convert a City object to JSON (for Hive storage)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'country': country,
      'state': state,
      'lat': latitude,
      'lon': longitude,
      'timezoneOffsetSeconds': timezoneOffsetSeconds,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is City &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              country == other.country &&
              state == other.state &&
              latitude == other.latitude &&
              longitude == other.longitude &&
              timezoneOffsetSeconds == other.timezoneOffsetSeconds;

  @override
  int get hashCode =>
      name.hashCode ^
      country.hashCode ^
      state.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      timezoneOffsetSeconds.hashCode;
}