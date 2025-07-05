// lib/models/daily_forecast.dart
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

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

  // Factory constructor to create a DailyForecast from JSON data
  factory DailyForecast.fromJson(Map<String, dynamic> json) {
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
      // FIX: Use Map<String, dynamic>.from for robustness if json is _Map<dynamic, dynamic>
      final Map<String, dynamic> safeJson = Map<String, dynamic>.from(json);
      final int dt = safeJson['dt'] as int;
      final DateTime time = DateTime.fromMillisecondsSinceEpoch(dt * 1000, isUtc: true);
      // FIX: Robustly cast the nested temp map
      final Map<String, dynamic> tempMap = Map<String, dynamic>.from(safeJson['temp']);
      final double minTemp = (tempMap['min'] as num).toDouble();
      final double maxTemp = (tempMap['max'] as num).toDouble();
      // FIX: Robustly cast the nested weather map
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
      logger.e('DailyForecast: Error parsing JSON: $e, JSON: $json', error: e);
      rethrow;
    }
  }

  // Method to convert a DailyForecast object to JSON
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

  // copyWith method for immutability
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