// lib/models/city_display_data.dart

// REMOVED: import 'package:flutter/foundation.dart'; // FIX: Removed unused import
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/utils/app_logger.dart';

// Simplified CityDisplayData for internal management within CityListManager
// It now only tracks the City and its saved status.
class CityDisplayData {
  final City city;
  bool isSaved; // Made mutable for internal CityListManager updates

  CityDisplayData({
    required this.city,
    this.isSaved = false,
  });

  // Factory constructor to create CityDisplayData from JSON (for Hive)
  factory CityDisplayData.fromJson(Map<String, dynamic> json) {
    try {
      final City city = City.fromJson(Map<String, dynamic>.from(json['city']));
      final bool isSaved = json['isSaved'] as bool;

      return CityDisplayData(
        city: city,
        isSaved: isSaved,
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
      'isSaved': isSaved,
    };
  }

  // copyWith method for immutability (if needed, but direct mutation might be simpler for 'isSaved')
  CityDisplayData copyWith({
    City? city,
    bool? isSaved,
  }) {
    return CityDisplayData(
      city: city ?? this.city,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CityDisplayData &&
              runtimeType == other.runtimeType &&
              city == other.city &&
              isSaved == other.isSaved;

  @override
  int get hashCode => city.hashCode ^ isSaved.hashCode;
}