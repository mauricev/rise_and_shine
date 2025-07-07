// lib/models/city_live_info.dart

import 'package:intl/intl.dart';
// REMOVED: import 'package:flutter/foundation.dart'; // FIX: Removed unused import


class CityLiveInfo {
  final DateTime currentTimeUtc;
  final int timezoneOffsetSeconds;
  final double? temperatureCelsius;
  final double? feelsLike;
  final int? humidity;
  final double? windSpeed;
  final String? windDirection;
  final String? condition;
  final String? description;
  final String? weatherIconCode;
  final double? uvIndex;
  final double? pop;
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
    this.uvIndex,
    this.pop,
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

  String get formattedLocalTime {
    final DateTime localTime = currentTimeUtc.add(Duration(seconds: timezoneOffsetSeconds));
    return DateFormat('h:mm a').format(localTime);
  }

  CityLiveInfo copyWith({
    DateTime? currentTimeUtc,
    int? timezoneOffsetSeconds,
    double? temperatureCelsius,
    double? feelsLike,
    int? humidity,
    double? windSpeed,
    String? windDirection,
    String? condition,
    String? description,
    String? weatherIconCode,
    double? uvIndex,
    double? pop,
    bool? isLoading,
    String? error,
  }) {
    return CityLiveInfo(
      currentTimeUtc: currentTimeUtc ?? this.currentTimeUtc,
      timezoneOffsetSeconds: timezoneOffsetSeconds ?? this.timezoneOffsetSeconds,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      feelsLike: feelsLike ?? this.feelsLike,
      humidity: humidity ?? this.humidity,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      condition: condition ?? this.condition,
      description: description ?? this.description,
      weatherIconCode: weatherIconCode ?? this.weatherIconCode,
      uvIndex: uvIndex ?? this.uvIndex,
      pop: pop ?? this.pop,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}