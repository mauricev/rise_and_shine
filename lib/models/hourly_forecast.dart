// lib/models/hourly_forecast.dart

import 'package:logger/logger.dart'; // For logging

class HourlyForecast {
  final DateTime time;
  final double temperatureCelsius;
  final String iconCode;
  // Removed: final String description; // Description is no longer needed per hour

  HourlyForecast({
    required this.time,
    required this.temperatureCelsius,
    required this.iconCode,
    // Removed: required this.description,
  });

  // Factory constructor to create an HourlyForecast from JSON data
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
      final int dt = json['dt'] as int;
      final DateTime time = DateTime.fromMillisecondsSinceEpoch(dt * 1000, isUtc: true);
      final double temperature = (json['temp'] as num).toDouble();
      final String icon = (json['weather'] as List<dynamic>)[0]['icon'] as String;
      // Removed: final String description = (json['weather'] as List<dynamic>)[0]['description'] as String;

      return HourlyForecast(
        time: time,
        temperatureCelsius: temperature,
        iconCode: icon,
        // Removed: description: description,
      );
    } catch (e) {
      logger.e('HourlyForecast: Error parsing JSON: $e, JSON: $json', error: e);
      rethrow; // Re-throw to propagate the error
    }
  }

  // Method to convert an HourlyForecast object to JSON (for Hive storage if needed later)
  Map<String, dynamic> toJson() {
    return {
      'dt': time.millisecondsSinceEpoch ~/ 1000, // Convert DateTime to Unix timestamp
      'temp': temperatureCelsius,
      'weather': [
        {'icon': iconCode /* Removed: , 'description': description */}
      ],
    };
  }

  // copyWith method for immutability
  HourlyForecast copyWith({
    DateTime? time,
    double? temperatureCelsius,
    String? iconCode,
    // Removed: String? description,
  }) {
    return HourlyForecast(
      time: time ?? this.time,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      iconCode: iconCode ?? this.iconCode,
      // Removed: description: description ?? this.description,
    );
  }
}
