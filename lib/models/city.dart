// lib/models/city.dart

import 'package:uuid/uuid.dart'; // Required for UUID generation

class City {
  final String id;
  final String name;
  final String country;
  final String? state; // State can be nullable for countries without states/provinces
  final double latitude;
  final double longitude;
  final int timezoneOffsetSeconds; // Offset from UTC in seconds

  City({
    String? id, // Optional for new cities, will be generated if null
    required this.name,
    required this.country,
    this.state,
    required this.latitude,
    required this.longitude,
    required this.timezoneOffsetSeconds,
  }) : id = id ?? const Uuid().v4(); // Generate UUID if not provided

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is City &&
        runtimeType == other.runtimeType &&
        id == other.id; // Compare by ID for unique identification
  }

  @override
  int get hashCode => id.hashCode;
}