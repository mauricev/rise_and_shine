// lib/models/hourly_forecast.dart
import 'package:flutter/foundation.dart';
// REMOVED: import 'package:logger/logger.dart'; // No longer needed here
import 'package:rise_and_shine/utils/app_logger.dart'; // NEW: Import the global logger


class HourlyForecast {
  final DateTime time;
  final double temperatureCelsius;
  final String iconCode;

  HourlyForecast({
    required this.time,
    required this.temperatureCelsius,
    required this.iconCode,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    // REMOVED: final Logger logger = Logger(...); // No longer declared here

    try {
      final Map<String, dynamic> safeJson = Map<String, dynamic>.from(json);
      final int dt = safeJson['dt'] as int;
      final DateTime time = DateTime.fromMillisecondsSinceEpoch(dt * 1000, isUtc: true);
      final double temperature = (safeJson['temp'] as num).toDouble();
      final Map<String, dynamic> weatherMap = Map<String, dynamic>.from((safeJson['weather'] as List<dynamic>)[0]);
      final String icon = weatherMap['icon'] as String;

      return HourlyForecast(
        time: time,
        temperatureCelsius: temperature,
        iconCode: icon,
      );
    } catch (e) {
      logger.e('HourlyForecast: Error parsing JSON: $e, JSON: $json', error: e); // Use global logger
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'dt': time.millisecondsSinceEpoch ~/ 1000,
      'temp': temperatureCelsius,
      'weather': [
        {'icon': iconCode}
      ],
    };
  }

  HourlyForecast copyWith({
    DateTime? time,
    double? temperatureCelsius,
    String? iconCode,
  }) {
    return HourlyForecast(
      time: time ?? this.time,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      iconCode: iconCode ?? this.iconCode,
    );
  }
}