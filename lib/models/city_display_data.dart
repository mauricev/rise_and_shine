// lib/models/city_display_data.dart

import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'dart:convert'; // For JSON encoding/decoding

class CityDisplayData {
  final City city;
  final CityLiveInfo liveInfo;
  final bool isSaved; // This property is still part of the model to track state in memory

  CityDisplayData({
    required this.city,
    required this.liveInfo,
    this.isSaved = false,
  });

  // NEW: Factory constructor to create a CityDisplayData object from a JSON map
  // When loading from Hive, we assume the loaded city IS saved, so set isSaved to true.
  factory CityDisplayData.fromJson(Map<String, dynamic> json) {
    // FIX: Explicitly cast nested map from Hive to Map<String, dynamic>
    final Map<String, dynamic> cityJsonMap = (json['city'] as Map).cast<String, dynamic>();

    return CityDisplayData(
      city: City.fromJson(cityJsonMap),
      // liveInfo is NOT persisted. It will be re-fetched/re-calculated on app start.
      // Initialize with default values, and the timezoneOffsetSeconds from the city.
      liveInfo: CityLiveInfo(
        currentTimeUtc: DateTime.now().toUtc(),
        timezoneOffsetSeconds: cityJsonMap['timezoneOffsetSeconds'] as int, // Use the casted map
        isLoading: true, // Set to true so UI shows loading while weather is fetched
      ),
      isSaved: true, // FIX: Assume true when loaded from saved list
    );
  }

  // NEW: Method to convert a CityDisplayData object to a JSON map
  // Only persist the 'city' data, as 'isSaved' is implied by being in the saved list.
  Map<String, dynamic> toJson() {
    return {
      'city': city.toJson(), // Convert City to JSON map
      // FIX: 'isSaved' is no longer persisted as it's redundant
    };
  }


  CityDisplayData copyWith({
    City? city,
    CityLiveInfo? liveInfo,
    bool? isSaved,
  }) {
    return CityDisplayData(
      city: city ?? this.city,
      liveInfo: liveInfo ?? this.liveInfo,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CityDisplayData &&
        runtimeType == other.runtimeType &&
        city == other.city &&
        liveInfo == other.liveInfo &&
        isSaved == other.isSaved;
  }

  @override
  int get hashCode => city.hashCode ^ liveInfo.hashCode ^ isSaved.hashCode;
}