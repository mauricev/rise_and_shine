// lib/models/daily_forecast.dart
import 'package:flutter/foundation.dart';
// REMOVED: import 'package:logger/logger.dart'; // No longer needed here
import 'package:rise_and_shine/utils/app_logger.dart'; // NEW: Import the global logger


class DailyForecast {
  final DateTime time;
  final double minTemperatureCelsius;
  final double maxTemperatureCelsius;
  final String iconCode;
  final String description;

  DailyForecast({
    required this.time,
    required this.minTemperatureCelsius,
    required this.maxTemperatureCelsius,
    required this.iconCode,
    required this.description,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    // REMOVED: final Logger logger = Logger(...); // No longer declared here

    try {
      final Map<String, dynamic> safeJson = Map<String, dynamic>.from(json);
      final int dt = safeJson['dt'] as int;
      final DateTime time = DateTime.fromMillisecondsSinceEpoch(dt * 1000, isUtc: true);
      final Map<String, dynamic> tempMap = Map<String, dynamic>.from(safeJson['temp']);
      final double minTemp = (tempMap['min'] as num).toDouble();
      final double maxTemp = (tempMap['max'] as num).toDouble();
      final Map<String, dynamic> weatherMap = Map<String, dynamic>.from((safeJson['weather'] as List<dynamic>)[0]);
      final String icon = weatherMap['icon'] as String;
      final String description = weatherMap['description'] as String;

      return DailyForecast(
        time: time,
        minTemperatureCelsius: minTemp,
        maxTemperatureCelsius: maxTemp,
        iconCode: icon,
        description: description,
      );
    } catch (e) {
      logger.e('DailyForecast: Error parsing JSON: $e, JSON: $json', error: e); // Use global logger
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'dt': time.millisecondsSinceEpoch ~/ 1000,
      'temp': {
        'min': minTemperatureCelsius,
        'max': maxTemperatureCelsius,
      },
      'weather': [
        {'icon': iconCode, 'description': description}
      ],
    };
  }

  DailyForecast copyWith({
    DateTime? time,
    double? minTemperatureCelsius,
    double? maxTemperatureCelsius,
    String? iconCode,
    String? description,
  }) {
    return DailyForecast(
      time: time ?? this.time,
      minTemperatureCelsius: minTemperatureCelsius ?? this.minTemperatureCelsius,
      maxTemperatureCelsius: maxTemperatureCelsius ?? this.maxTemperatureCelsius,
      iconCode: iconCode ?? this.iconCode,
      description: description ?? this.description,
    );
  }
}