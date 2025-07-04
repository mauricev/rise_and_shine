// lib/services/location_service_mobile.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/services/open_weather_service.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart'; // Mobile-specific import
import 'package:flutter/foundation.dart'; // NEW: Import for defaultTargetPlatform

// The actual LocationService implementation for mobile
class LocationService {
  static const String _ipApiUrl = 'https://ipapi.co/json/';

  final OpenWeatherService _openWeatherService;

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      // FIX: Corrected dateTimeFormat value
      dateTimeFormat: DateTimeFormat.onlyTime,
    ),
  );

  LocationService({required OpenWeatherService openWeatherService})
      : _openWeatherService = openWeatherService;

  Future<City?> getCurrentCityLocation() async {
    _logger.d('LocationService (Mobile): Attempting to get current city location.');

    City? detectedCity;

    detectedCity = await _getCurrentCityLocationMobile();

    // Fallback to IP lookup if precise location/reverse geocoding failed
    if (detectedCity == null) {
      _logger.d('LocationService (Mobile): Precise geolocation/reverse geocoding failed. Falling back to IP lookup.');
      detectedCity = await _getCityFromIpLookup();
    }

    return detectedCity;
  }

  // --- Mobile Implementation (Geolocator) ---
  Future<City?> _getCurrentCityLocationMobile() async {
    _logger.d('LocationService (Mobile): Attempting mobile geolocation...');
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.e('LocationService (Mobile): Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.e('LocationService (Mobile): Location permissions are denied by user.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.e('LocationService (Mobile): Location permissions are permanently denied, cannot request.');
      return null;
    }

    try {
      // FIX: Use defaultTargetPlatform to conditionally provide settings
      LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.low,
          forceLocationManager: false, // Use FusedLocationProviderClient if available
          // You can add more Android-specific settings here if needed
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.low,
          activityType: ActivityType.other,
          // You can add more iOS-specific settings here if needed
        );
      } else {
        // Fallback for other platforms (e.g., desktop, Fuchsia) if needed,
        // though geolocator primarily targets mobile/web.
        locationSettings = LocationSettings(
          accuracy: LocationAccuracy.low,
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      _logger.d('LocationService (Mobile): Mobile geolocation successful: ${position.latitude}, ${position.longitude}');

      // Use OpenWeatherService to reverse geocode these precise coordinates
      return await _openWeatherService.reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      _logger.e('LocationService (Mobile): Error getting mobile location: $e. Will try IP lookup as fallback.', error: e);
      return null;
    }
  }

  // --- Fallback Implementation (IP Lookup) ---
  Future<City?> _getCityFromIpLookup() async {
    _logger.d('LocationService (Mobile): Performing IP lookup for city details...');
    try {
      final http.Response response = await http.get(Uri.parse(_ipApiUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;

        final String? city = data['city'] as String?;
        final String? country = data['country_name'] as String?;
        final String? state = data['region'] as String?;
        final double? latitude = (data['latitude'] as num?)?.toDouble();
        final double? longitude = (data['longitude'] as num?)?.toDouble();
        final int? utcOffsetSeconds = _parseUtcOffset(data['utc_offset'] as String?);

        if (city != null && country != null && latitude != null && longitude != null && utcOffsetSeconds != null) {
          _logger.d('LocationService (Mobile): IP lookup successful: $city, $country');
          return City(
            name: city,
            country: country,
            state: state,
            latitude: latitude,
            longitude: longitude,
            timezoneOffsetSeconds: utcOffsetSeconds,
          );
        } else {
          _logger.e('LocationService (Mobile): IP lookup data incomplete or missing required fields: $data');
          return null;
        }
      } else {
        _logger.e('LocationService (Mobile): IP lookup failed with status: ${response.statusCode}, body: ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('LocationService (Mobile): Error during IP lookup: $e', error: e);
      return null;
    }
  }

  // Helper to parse UTC offset string like "+0200" to seconds
  int? _parseUtcOffset(String? utcOffset) {
    if (utcOffset == null || utcOffset.length != 5) return null;
    try {
      final int sign = utcOffset[0] == '+' ? 1 : -1;
      final int hours = int.parse(utcOffset.substring(1, 3));
      final int minutes = int.parse(utcOffset.substring(3, 5));
      return sign * (hours * 3600 + minutes * 60);
    } catch (e) {
      _logger.e('LocationService (Mobile): Error parsing UTC offset: $utcOffset, error: $e');
      return null;
    }
  }
}