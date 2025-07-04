// lib/models/city_live_info.dart

import 'package:intl/intl.dart'; // For date formatting
import 'package:logger/logger.dart';

// FIX: Define the Value<T> class
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

  // Factory constructor for loading state
  factory CityLiveInfo.loading(int timezoneOffsetSeconds) {
    return CityLiveInfo(
      currentTimeUtc: DateTime.now().toUtc(),
      timezoneOffsetSeconds: timezoneOffsetSeconds,
      isLoading: true,
    );
  }

  // FIX: Corrected factory constructor to create CityLiveInfo from JSON
  factory CityLiveInfo.fromJson(Map<String, dynamic> json) {
    final Logger logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTime,
      ),
    );

    try {
      return CityLiveInfo(
        currentTimeUtc: json['currentTimeUtc'] != null
            ? DateTime.parse(json['currentTimeUtc'] as String).toUtc()
            : null,
        timezoneOffsetSeconds: json['timezoneOffsetSeconds'] as int,
        temperatureCelsius: (json['temperatureCelsius'] as num?)?.toDouble(),
        feelsLike: (json['feelsLike'] as num?)?.toDouble(),
        humidity: json['humidity'] as int?,
        windSpeed: (json['windSpeed'] as num?)?.toDouble(),
        windDirection: json['windDirection'] as String?,
        condition: json['condition'] as String?,
        description: json['description'] as String?,
        weatherIconCode: json['weatherIconCode'] as String?,
        isLoading: json['isLoading'] as bool,
        error: json['error'] as String?,
      );
    } catch (e) {
      logger.e('CityLiveInfo: Error parsing JSON: $e, JSON: $json', error: e);
      rethrow;
    }
  }

  // FIX: Corrected method to convert CityLiveInfo to JSON
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