// lib/models/city.dart

// REMOVED: import 'package:logger/logger.dart'; // No longer needed here
import 'package:rise_and_shine/utils/app_logger.dart'; // NEW: Import the global logger


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

  factory City.fromJson(Map<String, dynamic> json) {
    // REMOVED: final Logger logger = Logger(...); // No longer declared here
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