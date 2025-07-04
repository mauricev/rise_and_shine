// lib/models/city_display_data.dart

import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'package:rise_and_shine/models/hourly_forecast.dart'; // FIX: Added missing import for HourlyForecast
import 'package:logger/logger.dart';

class CityDisplayData {
  final City city;
  final CityLiveInfo liveInfo;
  final bool isSaved;
  final List<HourlyForecast>? hourlyForecasts;

  CityDisplayData({
    required this.city,
    required this.liveInfo,
    this.isSaved = false,
    this.hourlyForecasts,
  });

  // Factory constructor to create CityDisplayData from JSON (for Hive)
  factory CityDisplayData.fromJson(Map<String, dynamic> json) {
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
      final City city = City.fromJson(json['city'] as Map<String, dynamic>);
      final CityLiveInfo liveInfo = CityLiveInfo.fromJson(json['liveInfo'] as Map<String, dynamic>);
      final bool isSaved = json['isSaved'] as bool;

      List<HourlyForecast>? parsedHourlyForecasts;
      if (json['hourlyForecasts'] != null) {
        parsedHourlyForecasts = (json['hourlyForecasts'] as List<dynamic>)
            .map((e) => HourlyForecast.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return CityDisplayData(
        city: city,
        liveInfo: liveInfo,
        isSaved: isSaved,
        hourlyForecasts: parsedHourlyForecasts,
      );
    } catch (e) {
      logger.e('CityDisplayData: Error parsing JSON: $e, JSON: $json', error: e);
      rethrow;
    }
  }

  // Method to convert CityDisplayData to JSON (for Hive)
  Map<String, dynamic> toJson() {
    return {
      'city': city.toJson(),
      'liveInfo': liveInfo.toJson(),
      'isSaved': isSaved,
      'hourlyForecasts': hourlyForecasts?.map((e) => e.toJson()).toList(),
    };
  }

  // copyWith method for immutability
  CityDisplayData copyWith({
    City? city,
    CityLiveInfo? liveInfo,
    bool? isSaved,
    Value<List<HourlyForecast>?>? hourlyForecasts,
  }) {
    return CityDisplayData(
      city: city ?? this.city,
      liveInfo: liveInfo ?? this.liveInfo,
      isSaved: isSaved ?? this.isSaved,
      hourlyForecasts: hourlyForecasts == null
          ? this.hourlyForecasts
          : hourlyForecasts.value,
    );
  }
}