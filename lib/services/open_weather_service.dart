// lib/services/open_weather_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rise_and_shine/models/city.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class OpenWeatherService {
  static const String _apiKey = '3a31498a9b35b3ecf49b42ff22562d2b';
  // FIX: Changed to OpenWeatherMap One Call API 3.0 endpoint
  static const String _oneCallBaseUrl = 'https://api.openweathermap.org/data/3.0/onecall';
  static const String _geocodingBaseUrl = 'https://api.openweathermap.org/geo/1.0/reverse';

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      // FIX: Replaced deprecated 'printTime: true' with 'dateTimeFormat: DateTimeFormat.onlyTime'
      dateTimeFormat: DateTimeFormat.onlyTime,
    ),
  );

  Future<Map<String, dynamic>> fetchCityTimeAndWeather(City city) async {
    // FIX: Using One Call API 3.0 endpoint.
    // Exclude other data (minutely, hourly, daily, alerts) to only get current weather
    // and reduce response size if only current weather is needed.
    // 'units=metric' is used for Celsius.
    final Uri uri = Uri.parse(
        '$_oneCallBaseUrl?lat=${city.latitude}&lon=${city.longitude}&exclude=minutely,hourly,daily,alerts&appid=$_apiKey&units=metric');

    if (kDebugMode) {
      _logger.d('OpenWeatherService: Fetching weather from One Call API 3.0: $uri');
      _logger.d('OpenWeatherService: Using API Key: $_apiKey');
    }

    final http.Response response = await http.get(uri);

    if (kDebugMode) {
      _logger.d('OpenWeatherService: Response status code: ${response.statusCode}');
      _logger.d('OpenWeatherService: Response body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;

      try {
        // FIX: Parse data from the 'current' object within the One Call API response
        final Map<String, dynamic> currentWeatherData = data['current'] as Map<String, dynamic>;
        final List<dynamic> weatherConditions = currentWeatherData['weather'] as List<dynamic>;
        final Map<String, dynamic> firstWeatherCondition = weatherConditions[0] as Map<String, dynamic>;

        final double temperature = (currentWeatherData['temp'] as num).toDouble();
        final double feelsLike = (currentWeatherData['feels_like'] as num).toDouble();
        final int humidity = currentWeatherData['humidity'] as int;
        final double windSpeed = (currentWeatherData['wind_speed'] as num).toDouble();
        final int? windDegrees = currentWeatherData['wind_deg'] as int?;
        final String condition = firstWeatherCondition['main'] as String;
        final String description = firstWeatherCondition['description'] as String;
        final String weatherIconCode = firstWeatherCondition['icon'] as String;
        // FIX: Timezone offset is at the root level of the One Call API response
        final int timezoneOffset = data['timezone_offset'] as int;

        final Map<String, dynamic> parsedData = {
          'temperatureCelsius': temperature,
          'feelsLike': feelsLike,
          'humidity': humidity,
          'windSpeed': windSpeed,
          'windDirection': _degreesToCardinal(windDegrees),
          'condition': condition,
          'description': description,
          'weatherIconCode': weatherIconCode,
          'timezoneOffsetSeconds': timezoneOffset,
        };

        if (kDebugMode) {
          _logger.d('OpenWeatherService: Successfully parsed weather data: $parsedData');
        }
        return parsedData;
      } catch (e) {
        if (kDebugMode) {
          _logger.e('OpenWeatherService: Error parsing weather data for ${city.name}: $e', error: e);
          _logger.e('OpenWeatherService: Raw data that caused parsing error: $data');
        }
        throw Exception('Failed to parse weather data for ${city.name}: $e');
      }
    } else {
      final Map<String, dynamic> errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final String errorMessage = errorData['message'] as String? ?? 'Unknown error';
      if (kDebugMode) {
        _logger.e('OpenWeatherService: Failed to load weather data for ${city.name}. Status: ${response.statusCode}, Message: $errorMessage');
      }
      throw Exception('Failed to load weather data for ${city.name}: $errorMessage (Status: ${response.statusCode})');
    }
  }

  // NEW: Method for reverse geocoding (lat/lon to city/country/timezone)
  Future<City?> reverseGeocode(double latitude, double longitude) async {
    // limit=1 to get only the most relevant result
    final Uri uri = Uri.parse(
        '$_geocodingBaseUrl?lat=$latitude&lon=$longitude&limit=1&appid=$_apiKey');

    if (kDebugMode) {
      _logger.d('OpenWeatherService: Reverse geocoding from: $uri');
    }

    final http.Response response = await http.get(uri);

    if (kDebugMode) {
      _logger.d('OpenWeatherService: Reverse geocoding response status code: ${response.statusCode}');
      _logger.d('OpenWeatherService: Reverse geocoding response body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      if (data.isEmpty) {
        _logger.d('OpenWeatherService: No geocoding results found for $latitude, $longitude.');
        return null;
      }

      try {
        final Map<String, dynamic> cityData = (data[0] as Map).cast<String, dynamic>();
        final String name = cityData['name'] as String;
        final String country = cityData['country'] as String;
        final String? state = cityData['state'] as String?; // State can be null

        // For timezone offset, we need to make another call to the weather API
        // as the geocoding API doesn't directly provide timezone offset.
        // FIX: Using One Call API 3.0 for timezone offset as well.
        final Uri timezoneUri = Uri.parse(
            '$_oneCallBaseUrl?lat=$latitude&lon=$longitude&exclude=current,minutely,hourly,daily,alerts&appid=$_apiKey');
        final http.Response timezoneResponse = await http.get(timezoneUri);

        if (timezoneResponse.statusCode == 200) {
          final Map<String, dynamic> timezoneData = jsonDecode(timezoneResponse.body) as Map<String, dynamic>;
          final int timezoneOffsetSeconds = timezoneData['timezone_offset'] as int;

          return City(
            name: name,
            country: country,
            state: state,
            latitude: latitude,
            longitude: longitude,
            timezoneOffsetSeconds: timezoneOffsetSeconds,
          );
        } else {
          final Map<String, dynamic> errorData = jsonDecode(timezoneResponse.body) as Map<String, dynamic>;
          final String errorMessage = errorData['message'] as String? ?? 'Unknown timezone error';
          _logger.e('OpenWeatherService: Failed to get timezone for $name. Status: ${timezoneResponse.statusCode}, Message: $errorMessage');
          throw Exception('Failed to get timezone for $name: $errorMessage');
        }
      } catch (e) {
        _logger.e('OpenWeatherService: Error parsing geocoding data for $latitude, $longitude: $e', error: e);
        throw Exception('Failed to parse geocoding data: ${e.toString()}');
      }
    } else {
      final Map<String, dynamic> errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final String errorMessage = errorData['message'] as String? ?? 'Unknown error';
      _logger.e('OpenWeatherService: Failed to reverse geocode $latitude, $longitude. Status: ${response.statusCode}, Message: $errorMessage');
      throw Exception('Failed to reverse geocode coordinates: $errorMessage (Status: ${response.statusCode})');
    }
  }

  String _degreesToCardinal(int? degrees) {
    if (degrees == null) return 'N/A';
    if (degrees >= 337.5 || degrees < 22.5) return 'N';
    if (degrees >= 22.5 && degrees < 67.5) return 'NE';
    if (degrees >= 67.5 && degrees < 112.5) return 'E';
    if (degrees >= 112.5 && degrees < 157.5) return 'SE';
    if (degrees >= 157.5 && degrees < 202.5) return 'S';
    if (degrees >= 202.5 && degrees < 247.5) return 'SW';
    if (degrees >= 247.5 && degrees < 292.5) return 'W';
    if (degrees >= 292.5 && degrees < 337.5) return 'NW';
    return 'N/A';
  }
}
