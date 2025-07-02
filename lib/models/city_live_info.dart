// lib/models/city_live_info.dart

// Define a simple Value wrapper for nullable fields in copyWith
// This allows us to distinguish between not providing a value
// and explicitly providing null as a value.
class Value<T> {
  final T value;
  const Value(this.value);
}

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
    // FIX: Removed seconds and 'Time:' prefix (from previous iteration)
    return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  CityLiveInfo copyWith({
    DateTime? currentTimeUtc,
    int? timezoneOffsetSeconds,
    // FIX: Use Value<double?> for nullable fields to implement sentinel pattern
    Value<double?>? temperatureCelsius,
    Value<double?>? feelsLike,
    Value<int?>? humidity,
    Value<double?>? windSpeed,
    Value<String?>? windDirection,
    Value<String?>? condition,
    Value<String?>? description,
    Value<String?>? weatherIconCode,
    bool? isLoading,
    Value<String?>? error, // Apply sentinel to error as well
  }) {
    return CityLiveInfo(
      currentTimeUtc: currentTimeUtc ?? this.currentTimeUtc,
      timezoneOffsetSeconds: timezoneOffsetSeconds ?? this.timezoneOffsetSeconds,
      // FIX: Apply sentinel logic: if Value is provided, use its value. Otherwise, keep existing.
      temperatureCelsius: temperatureCelsius != null ? temperatureCelsius.value : this.temperatureCelsius,
      feelsLike: feelsLike != null ? feelsLike.value : this.feelsLike,
      humidity: humidity != null ? humidity.value : this.humidity,
      windSpeed: windSpeed != null ? windSpeed.value : this.windSpeed,
      windDirection: windDirection != null ? windDirection.value : this.windDirection,
      condition: condition != null ? condition.value : this.condition,
      description: description != null ? description.value : this.description,
      weatherIconCode: weatherIconCode != null ? weatherIconCode.value : this.weatherIconCode,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error.value : this.error,
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