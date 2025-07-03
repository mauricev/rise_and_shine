// lib/models/city.dart

import 'dart:convert'; // For JSON encoding/decoding

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

  // NEW: Factory constructor to create a City object from a JSON map
  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'] as String,
      country: json['country'] as String,
      state: json['state'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timezoneOffsetSeconds: json['timezoneOffsetSeconds'] as int,
    );
  }

  // NEW: Method to convert a City object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'country': country,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'timezoneOffsetSeconds': timezoneOffsetSeconds,
    };
  }

  // Optional: For easier debugging and logging
  @override
  String toString() {
    return 'City(name: $name, country: $country, state: $state, lat: $latitude, lon: $longitude, timezoneOffset: $timezoneOffsetSeconds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is City &&
        runtimeType == other.runtimeType &&
        name == other.name &&
        country == other.country &&
        state == other.state &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        timezoneOffsetSeconds == other.timezoneOffsetSeconds;
  }

  @override
  int get hashCode =>
      name.hashCode ^
      country.hashCode ^
      state.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      timezoneOffsetSeconds.hashCode;
}