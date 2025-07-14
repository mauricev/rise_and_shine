// lib/models/city_live_info.dart

import 'package:intl/intl.dart';

class CityLiveInfo {
  final int timezoneOffsetSeconds;
  final double? temperatureCelsius;
  final double? feelsLike;
  final int? humidity;
  final double? windSpeed;
  final String? windDirection;
  final String? description;
  final String? weatherIconCode;
  final double? uvIndex;
  final bool isLoading;
  final String? error;
  final int? sunriseTimeEpoch;
  final int? sunsetTimeEpoch;
  final bool isDay; // This is the property we need to verify

  CityLiveInfo({
    required this.timezoneOffsetSeconds,
    this.temperatureCelsius,
    this.feelsLike,
    this.humidity,
    this.windSpeed,
    this.windDirection,
    this.description,
    this.weatherIconCode,
    this.uvIndex,
    this.isLoading = false,
    this.error,
    this.sunriseTimeEpoch,
    this.sunsetTimeEpoch,
    required this.isDay, // This is explicitly required now
  });

  // Factory constructor for loading state
  factory CityLiveInfo.loading() {
    return CityLiveInfo(
      timezoneOffsetSeconds: 0,
      isLoading: true,
      isDay: true, // Default to day during loading
    );
  }

  // Factory constructor for error state
  factory CityLiveInfo.error(String message) {
    return CityLiveInfo(
      timezoneOffsetSeconds: 0,
      error: message,
      isDay: true, // Default to day during error
    );
  }

  // Helper to get formatted local time
  String get formattedLocalTime {
    if (isLoading || error != null) return 'N/A';
    final now = DateTime.now().toUtc();
    final localTime = now.add(Duration(seconds: timezoneOffsetSeconds));
    return DateFormat('h:mm a').format(localTime);
  }

  // CopyWith method for immutability
  CityLiveInfo copyWith({
    int? timezoneOffsetSeconds,
    double? temperatureCelsius,
    double? feelsLike,
    int? humidity,
    double? windSpeed,
    String? windDirection,
    String? description,
    String? weatherIconCode,
    double? uvIndex,
    bool? isLoading,
    String? error,
    int? sunriseTimeEpoch,
    int? sunsetTimeEpoch,
    bool? isDay,
  }) {
    return CityLiveInfo(
      timezoneOffsetSeconds: timezoneOffsetSeconds ?? this.timezoneOffsetSeconds,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      feelsLike: feelsLike ?? this.feelsLike,
      humidity: humidity ?? this.humidity,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      description: description ?? this.description,
      weatherIconCode: weatherIconCode ?? this.weatherIconCode,
      uvIndex: uvIndex ?? this.uvIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      sunriseTimeEpoch: sunriseTimeEpoch ?? this.sunriseTimeEpoch,
      sunsetTimeEpoch: sunsetTimeEpoch ?? this.sunsetTimeEpoch,
      isDay: isDay ?? this.isDay,
    );
  }

  @override
  String toString() {
    return 'CityLiveInfo(temp: ${temperatureCelsius?.toStringAsFixed(1)}C, '
        'feelsLike: ${feelsLike?.toStringAsFixed(1)}C, '
        'humidity: $humidity%, '
        'wind: ${windSpeed?.toStringAsFixed(1)} ${windDirection ?? 'N/A'}, '
        'description: ${description ?? 'N/A'}, '
        'icon: ${weatherIconCode ?? 'N/A'}, '
        'isDay: $isDay, ' // Added for debugging
        'uv: ${uvIndex ?? 'N/A'}, '
        'isLoading: $isLoading, '
        'error: ${error ?? 'N/A'})';
  }
}