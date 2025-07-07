// lib/models/daily_forecast.dart

class DailyForecast {
  final DateTime time;
  final double minTemperatureCelsius; // This will now hold the converted temperature
  final double maxTemperatureCelsius; // This will now hold the converted temperature
  final String iconCode;
  final double? pop; // NEW: Probability of Precipitation
  final double? windSpeed; // NEW: Wind Speed (max daily wind speed)

  DailyForecast({
    required this.time,
    required this.minTemperatureCelsius,
    required this.maxTemperatureCelsius,
    required this.iconCode,
    this.pop, // NEW
    this.windSpeed, // NEW
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      time: DateTime.fromMillisecondsSinceEpoch((json['dt'] as int) * 1000, isUtc: true),
      minTemperatureCelsius: (json['temp']['min'] as num).toDouble(),
      maxTemperatureCelsius: (json['temp']['max'] as num).toDouble(),
      iconCode: (json['weather'] as List<dynamic>)[0]['icon'] as String,
      pop: (json['pop'] as num?)?.toDouble(), // NEW: Parse pop
      windSpeed: (json['wind_speed'] as num?)?.toDouble(), // NEW: Parse wind_speed
    );
  }

  DailyForecast copyWith({
    DateTime? time,
    double? minTemperatureCelsius,
    double? maxTemperatureCelsius,
    String? iconCode,
    double? pop, // NEW
    double? windSpeed, // NEW
  }) {
    return DailyForecast(
      time: time ?? this.time,
      minTemperatureCelsius: minTemperatureCelsius ?? this.minTemperatureCelsius,
      maxTemperatureCelsius: maxTemperatureCelsius ?? this.maxTemperatureCelsius,
      iconCode: iconCode ?? this.iconCode,
      pop: pop ?? this.pop, // NEW
      windSpeed: windSpeed ?? this.windSpeed, // NEW
    );
  }
}