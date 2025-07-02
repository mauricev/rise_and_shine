// lib/models/city_display_data.dart

import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_live_info.dart';

class CityDisplayData {
  final City city;
  final CityLiveInfo liveInfo;

  CityDisplayData({
    required this.city,
    required this.liveInfo,
  });

  CityDisplayData copyWith({
    City? city,
    CityLiveInfo? liveInfo,
  }) {
    return CityDisplayData(
      city: city ?? this.city,
      liveInfo: liveInfo ?? this.liveInfo,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CityDisplayData &&
        runtimeType == other.runtimeType &&
        city == other.city && // Compare by city (which uses its ID for equality)
        liveInfo == other.liveInfo;
  }

  @override
  int get hashCode => city.hashCode ^ liveInfo.hashCode;
}