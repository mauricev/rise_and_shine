// lib/models/city_weather_data.dart

import 'package:flutter/foundation.dart'; // For @immutable and listEquals
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'package:rise_and_shine/models/hourly_forecast.dart';
import 'package:rise_and_shine/models/daily_forecast.dart';
import 'package:rise_and_shine/models/weather_alert.dart'; // NEW: Import WeatherAlert

@immutable
class CityWeatherData {
  final City city;
  final CityLiveInfo liveInfo;
  final List<HourlyForecast> hourlyForecasts;
  final List<DailyForecast> dailyForecasts;
  final List<WeatherAlert> alerts; // NEW: List of weather alerts

  const CityWeatherData({
    required this.city,
    required this.liveInfo,
    this.hourlyForecasts = const [],
    this.dailyForecasts = const [],
    this.alerts = const [], // NEW: Initialize alerts with an empty list
  });

  CityWeatherData copyWith({
    City? city,
    CityLiveInfo? liveInfo,
    List<HourlyForecast>? hourlyForecasts,
    List<DailyForecast>? dailyForecasts,
    List<WeatherAlert>? alerts, // NEW: Add alerts to copyWith
  }) {
    return CityWeatherData(
      city: city ?? this.city,
      liveInfo: liveInfo ?? this.liveInfo,
      hourlyForecasts: hourlyForecasts ?? this.hourlyForecasts,
      dailyForecasts: dailyForecasts ?? this.dailyForecasts,
      alerts: alerts ?? this.alerts, // NEW: Copy alerts
    );
  }

  @override
  String toString() {
    return 'CityWeatherData(city: ${city.name}, liveInfo: $liveInfo, hourlyForecasts: ${hourlyForecasts.length}, dailyForecasts: ${dailyForecasts.length}, alerts: ${alerts.length})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CityWeatherData &&
              runtimeType == other.runtimeType &&
              city == other.city &&
              liveInfo == other.liveInfo &&
              listEquals(hourlyForecasts, other.hourlyForecasts) &&
              listEquals(dailyForecasts, other.dailyForecasts) &&
              listEquals(alerts, other.alerts); // NEW: Include alerts in equality check

  @override
  int get hashCode => Object.hash(city, liveInfo, Object.hashAll(hourlyForecasts), Object.hashAll(dailyForecasts), Object.hashAll(alerts)); // NEW: Include alerts in hashCode
}