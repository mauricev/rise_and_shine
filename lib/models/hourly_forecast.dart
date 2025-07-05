// lib/models/hourly_forecast.dart
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

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
      final double temperature = (safeJson['temp'] as num).toDouble();
      // FIX: Robustly cast the nested weather map
      final Map<String, dynamic> weatherMap = Map<String, dynamic>.from((safeJson['weather'] as List<dynamic>)[0]);
      final String icon = weatherMap['icon'] as String;

      return HourlyForecast(
        time: time,
        temperatureCelsius: temperature,
        iconCode: icon,
      );
    } catch (e) {
      logger.e('HourlyForecast: Error parsing JSON: $e, JSON: $json', error: e);
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