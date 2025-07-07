// lib/models/hourly_forecast.dart

class HourlyForecast {
  final DateTime time;
  final double temperatureCelsius; // This will now hold the converted temperature
  final String iconCode;
  final double? pop; // NEW: Probability of Precipitation
  final double? windSpeed; // NEW: Wind Speed

  HourlyForecast({
    required this.time,
    required this.temperatureCelsius,
    required this.iconCode,
    this.pop, // NEW
    this.windSpeed, // NEW
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      time: DateTime.fromMillisecondsSinceEpoch((json['dt'] as int) * 1000, isUtc: true),
      temperatureCelsius: (json['temp'] as num).toDouble(),
      iconCode: (json['weather'] as List<dynamic>)[0]['icon'] as String,
      pop: (json['pop'] as num?)?.toDouble(), // NEW: Parse pop
      windSpeed: (json['wind_speed'] as num?)?.toDouble(), // NEW: Parse wind_speed
    );
  }

  HourlyForecast copyWith({
    DateTime? time,
    double? temperatureCelsius,
    String? iconCode,
    double? pop, // NEW
    double? windSpeed, // NEW
  }) {
    return HourlyForecast(
      time: time ?? this.time,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      iconCode: iconCode ?? this.iconCode,
      pop: pop ?? this.pop, // NEW
      windSpeed: windSpeed ?? this.windSpeed, // NEW
    );
  }
}