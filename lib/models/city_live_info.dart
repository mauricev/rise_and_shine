// lib/models/city_live_info.dart

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

  String get formattedLocalTime {
    final localTime = currentTimeUtc.toUtc().add(Duration(seconds: timezoneOffsetSeconds));
    return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}';
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
    bool? isLoading,
    String? error,
  }) {
    return CityLiveInfo(
      currentTimeUtc: currentTimeUtc ?? this.currentTimeUtc,
      timezoneOffsetSeconds: timezoneOffsetSeconds ?? this.timezoneOffsetSeconds,
      temperatureCelsius: temperatureCelsius,
      feelsLike: feelsLike,
      humidity: humidity,
      windSpeed: windSpeed,
      windDirection: windDirection,
      condition: condition,
      description: description,
      weatherIconCode: weatherIconCode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CityLiveInfo &&
        runtimeType == other.runtimeType &&
        currentTimeUtc == other.currentTimeUtc &&
        timezoneOffsetSeconds == other.timezoneOffsetSeconds &&
        temperatureCelsius == other.temperatureCelsius &&
        feelsLike == other.feelsLike &&
        humidity == other.humidity &&
        windSpeed == other.windSpeed &&
        windDirection == other.windDirection &&
        condition == other.condition &&
        description == other.description &&
        weatherIconCode == other.weatherIconCode &&
        isLoading == other.isLoading &&
        error == other.error;
  }

  @override
  int get hashCode =>
      currentTimeUtc.hashCode ^
      timezoneOffsetSeconds.hashCode ^
      temperatureCelsius.hashCode ^
      feelsLike.hashCode ^
      humidity.hashCode ^
      windSpeed.hashCode ^
      windDirection.hashCode ^
      condition.hashCode ^
      description.hashCode ^
      weatherIconCode.hashCode ^
      isLoading.hashCode ^
      error.hashCode;
}