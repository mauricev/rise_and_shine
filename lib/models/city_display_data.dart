// lib/models/city_display_data.dart

import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_live_info.dart';

class CityDisplayData {
  final City city;
  final CityLiveInfo liveInfo;
  final bool isSaved; // New field

  CityDisplayData({
    required this.city,
    required this.liveInfo,
    this.isSaved = false, // Default to false if not provided
  });

  CityDisplayData copyWith({
    City? city,
    CityLiveInfo? liveInfo,
    bool? isSaved, // New field in copyWith
  }) {
    return CityDisplayData(
      city: city ?? this.city,
      liveInfo: liveInfo ?? this.liveInfo,
      isSaved: isSaved ?? this.isSaved, // Copy new field
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CityDisplayData &&
        runtimeType == other.runtimeType &&
        city == other.city &&
        liveInfo == other.liveInfo &&
        isSaved == other.isSaved; // Include in equality check
  }

  @override
  int get hashCode => city.hashCode ^ liveInfo.hashCode ^ isSaved.hashCode; // Include in hash code
}