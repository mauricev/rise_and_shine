// lib/models/city_display_data.dart

import 'package:flutter/foundation.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'package:rise_and_shine/models/hourly_forecast.dart';
import 'package:rise_and_shine/models/daily_forecast.dart';
import 'package:logger/logger.dart';

class CityDisplayData {
  final City city;
  final CityLiveInfo liveInfo;
  final bool isSaved;
  final List<HourlyForecast>? hourlyForecasts;
  final List<DailyForecast>? dailyForecasts;

  CityDisplayData({
    required this.city,
    required this.liveInfo,
    this.isSaved = false,
    this.hourlyForecasts,
    this.dailyForecasts,
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
      // FIX: Use Map<String, dynamic>.from for all nested map deserializations
      final City city = City.fromJson(Map<String, dynamic>.from(json['city']));
      final CityLiveInfo liveInfo = CityLiveInfo.fromJson(Map<String, dynamic>.from(json['liveInfo']));
      final bool isSaved = json['isSaved'] as bool;

      List<HourlyForecast>? parsedHourlyForecasts;
      if (json['hourlyForecasts'] != null) {
        parsedHourlyForecasts = (json['hourlyForecasts'] as List<dynamic>)
            .map((e) => HourlyForecast.fromJson(Map<String, dynamic>.from(e))) // FIX: Cast 'e'
            .toList();
      }

      List<DailyForecast>? parsedDailyForecasts;
      if (json['dailyForecasts'] != null) {
        parsedDailyForecasts = (json['dailyForecasts'] as List<dynamic>)
            .map((e) => DailyForecast.fromJson(Map<String, dynamic>.from(e))) // FIX: Cast 'e'
            .toList();
      }

      return CityDisplayData(
        city: city,
        liveInfo: liveInfo,
        isSaved: isSaved,
        hourlyForecasts: parsedHourlyForecasts,
        dailyForecasts: parsedDailyForecasts,
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
      'dailyForecasts': dailyForecasts?.map((e) => e.toJson()).toList(),
    };
  }

  // copyWith method for immutability
  CityDisplayData copyWith({
    City? city,
    CityLiveInfo? liveInfo,
    bool? isSaved,
    Value<List<HourlyForecast>?>? hourlyForecasts,
    Value<List<DailyForecast>?>? dailyForecasts,
  }) {
    return CityDisplayData(
      city: city ?? this.city,
      liveInfo: liveInfo ?? this.liveInfo,
      isSaved: isSaved ?? this.isSaved,
      hourlyForecasts: hourlyForecasts == null
          ? this.hourlyForecasts
          : hourlyForecasts.value,
      dailyForecasts: dailyForecasts == null
          ? this.dailyForecasts
          : dailyForecasts.value,
    );
  }
}

// ListExtension is correctly defined in lib/managers/city_list_manager.dart