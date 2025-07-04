// lib/services/location_service_web.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/services/open_weather_service.dart';
import 'package:logger/logger.dart';
import 'dart:html' as html; // Web-specific import

// The actual LocationService implementation for web
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
      printTime: true,
    ),
  );

  LocationService({required OpenWeatherService openWeatherService})
      : _openWeatherService = openWeatherService;

  Future<City?> getCurrentCityLocation() async {
    _logger.d('LocationService (Web): Attempting to get current city location.');

    City? detectedCity;

    detectedCity = await _getCurrentCityLocationWeb();

    // Fallback to IP lookup if precise location/reverse geocoding failed
    if (detectedCity == null) {
      _logger.d('LocationService (Web): Precise geolocation/reverse geocoding failed. Falling back to IP lookup.');
      detectedCity = await _getCityFromIpLookup();
    }

    return detectedCity;
  }

  // --- Web Implementation (Browser Geolocation) ---
  Future<City?> _getCurrentCityLocationWeb() async {
    _logger.d('LocationService (Web): Attempting web geolocation...');
    try {
      final html.Geolocation geolocation = html.window.navigator.geolocation;
      final html.Geoposition position = await geolocation.getCurrentPosition();

      final double latitude = position.coords!.latitude!.toDouble();
      final double longitude = position.coords!.longitude!.toDouble();
      _logger.d('LocationService (Web): Web geolocation successful: $latitude, $longitude');

      // Use OpenWeatherService to reverse geocode these precise coordinates
      return await _openWeatherService.reverseGeocode(latitude, longitude);
    } catch (e) {
      _logger.e('LocationService (Web): Web geolocation failed: $e. Will try IP lookup as fallback.', error: e);
      return null;
    }
  }

  // --- Fallback Implementation (IP Lookup) ---
  Future<City?> _getCityFromIpLookup() async {
    _logger.d('LocationService (Web): Performing IP lookup for city details...');
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
          _logger.d('LocationService (Web): IP lookup successful: $city, $country');
          return City(
            name: city,
            country: country,
            state: state,
            latitude: latitude,
            longitude: longitude,
            timezoneOffsetSeconds: utcOffsetSeconds,
          );
        } else {
          _logger.e('LocationService (Web): IP lookup data incomplete or missing required fields: $data');
          return null;
        }
      } else {
        _logger.e('LocationService (Web): IP lookup failed with status: ${response.statusCode}, body: ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('LocationService (Web): Error during IP lookup: $e', error: e);
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
      _logger.e('LocationService (Web): Error parsing UTC offset: $utcOffset, error: $e');
      return null;
    }
  }
}