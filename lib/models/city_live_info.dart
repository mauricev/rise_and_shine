// lib/models/city_live_info.dart

import 'package:intl/intl.dart';
// REMOVED: import 'package:logger/logger.dart'; // No longer needed here
import 'package:rise_and_shine/utils/app_logger.dart'; // NEW: Import the global logger


/// A wrapper for nullable values in copyWith methods to distinguish
/// between null (meaning "don't change") and Value(null) (meaning "set to null").
class Value<T> {
  final T value;
  const Value(this.value);
}

class CityLiveInfo {
  final DateTime? currentTimeUtc;
  final int timezoneOffsetSeconds;
  final double? temperatureCelsius;
  final double? feelsLike;
  final int? humidity;
  final double? windSpeed;
  final String? windDirection;
  final String? condition;
  final String? description;
  final String? weatherIconCode;
  final bool isLoading;
  final String? error;

  CityLiveInfo({
    required this.currentTimeUtc,
    required this.timezoneOffsetSeconds,
    this.temperatureCelsius,
    this.feelsLike,
    this.humidity,
    this.windSpeed,
    this.windDirection,
    this.condition,
    this.description,
    this.weatherIconCode,
    this.isLoading = false,
    this.error,
  });

  factory CityLiveInfo.loading(int timezoneOffsetSeconds) {
    return CityLiveInfo(
      currentTimeUtc: DateTime.now().toUtc(),
      timezoneOffsetSeconds: timezoneOffsetSeconds,
      isLoading: true,
    );
  }

  factory CityLiveInfo.fromJson(Map<String, dynamic> json) {
    // REMOVED: final Logger logger = Logger(...); // No longer declared here

    try {
      final Map<String, dynamic> safeJson = Map<String, dynamic>.from(json);
      return CityLiveInfo(
        currentTimeUtc: safeJson['currentTimeUtc'] != null
            ? DateTime.parse(safeJson['currentTimeUtc'] as String).toUtc()
            : null,
        timezoneOffsetSeconds: safeJson['timezoneOffsetSeconds'] as int,
        temperatureCelsius: (safeJson['temperatureCelsius'] as num?)?.toDouble(),
        feelsLike: (safeJson['feelsLike'] as num?)?.toDouble(),
        humidity: safeJson['humidity'] as int?,
        windSpeed: (safeJson['windSpeed'] as num?)?.toDouble(),
        windDirection: safeJson['windDirection'] as String?,
        condition: safeJson['condition'] as String?,
        description: safeJson['description'] as String?,
        weatherIconCode: safeJson['weatherIconCode'] as String?,
        isLoading: safeJson['isLoading'] as bool,
        error: safeJson['error'] as String?,
      );
    } catch (e) {
      logger.e('CityLiveInfo: Error parsing JSON: $e, JSON: $json', error: e); // Use global logger
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'currentTimeUtc': currentTimeUtc?.toIso8601String(),
      'timezoneOffsetSeconds': timezoneOffsetSeconds,
      'temperatureCelsius': temperatureCelsius,
      'feelsLike': feelsLike,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'windDirection': windDirection,
      'condition': condition,
      'description': description,
      'weatherIconCode': weatherIconCode,
      'isLoading': isLoading,
      'error': error,
    };
  }

  String get formattedLocalTime {
    if (currentTimeUtc == null) return 'N/A';
    final DateTime localTime = currentTimeUtc!.add(Duration(seconds: timezoneOffsetSeconds));
    return DateFormat('hh:mm a').format(localTime);
  }

  CityLiveInfo copyWith({
    DateTime? currentTimeUtc,
    int? timezoneOffsetSeconds,
    Value<double?>? temperatureCelsius,
    Value<double?>? feelsLike,
    Value<int?>? humidity,
    Value<double?>? windSpeed,
    Value<String?>? windDirection,
    Value<String?>? condition,
    Value<String?>? description,
    Value<String?>? weatherIconCode,
    bool? isLoading,
    Value<String?>? error,
  }) {
    return CityLiveInfo(
      currentTimeUtc: currentTimeUtc ?? this.currentTimeUtc,
      timezoneOffsetSeconds: timezoneOffsetSeconds ?? this.timezoneOffsetSeconds,
      temperatureCelsius: temperatureCelsius != null ? temperatureCelsius.value : this.temperatureCelsius,
      feelsLike: feelsLike != null ? feelsLike.value : this.feelsLike,
      humidity: humidity != null ? humidity.value : this.humidity,
      windSpeed: windSpeed != null ? windSpeed.value : this.windSpeed,
      windDirection: windDirection != null ? windDirection.value : this.windDirection,
      condition: condition != null ? condition.value : this.condition,
      description: description != null ? description.value : this.description,
      weatherIconCode: weatherIconCode != null ? weatherIconCode.value : this.weatherIconCode,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error.value : this.error,
    );
  }
}