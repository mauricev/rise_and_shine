// lib/services/open_weather_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rise_and_shine/models/city.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class OpenWeatherService {
  static const String _apiKey = '4a2b73e379f5b7f36dd6e51e291e987e';
  static const String _weatherBaseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  // NEW: OpenWeatherMap Geocoding API endpoint
  static const String _geocodingBaseUrl = 'https://api.openweathermap.org/geo/1.0/reverse';

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

  Future<Map<String, dynamic>> fetchCityTimeAndWeather(City city) async {
    final Uri uri = Uri.parse(
        '$_weatherBaseUrl?lat=${city.latitude}&lon=${city.longitude}&appid=$_apiKey&units=metric');

    if (kDebugMode) {
      _logger.d('OpenWeatherService: Fetching weather from: $uri');
      _logger.d('OpenWeatherService: Using API Key: $_apiKey'); // Log API key for debugging
    }

    final http.Response response = await http.get(uri);

    if (kDebugMode) {
      _logger.d('OpenWeatherService: Response status code: ${response.statusCode}');
      _logger.d('OpenWeatherService: Response body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;

      try {
        final double temperature = (data['main']['temp'] as num).toDouble();
        final double feelsLike = (data['main']['feels_like'] as num).toDouble();
        final int humidity = data['main']['humidity'] as int;
        final double windSpeed = (data['wind']['speed'] as num).toDouble();
        final int? windDegrees = data['wind']['deg'] as int?;
        final String condition = data['weather'][0]['main'] as String;
        final String description = data['weather'][0]['description'] as String;
        final String weatherIconCode = data['weather'][0]['icon'] as String; // Added icon code
        final int timezoneOffset = data['timezone'] as int; // This is in seconds

        final Map<String, dynamic> parsedData = {
          'temperatureCelsius': temperature,
          'feelsLike': feelsLike,
          'humidity': humidity,
          'windSpeed': windSpeed,
          'windDirection': _degreesToCardinal(windDegrees),
          'condition': condition,
          'description': description,
          'weatherIconCode': weatherIconCode, // Include icon code in response
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
  // This method will be used by LocationService to convert precise coordinates to a City object.
  Future<City?> reverseGeocode(double latitude, double longitude) async {
    _logger.d('OpenWeatherService: Starting reverse geocoding and timezone lookup for $latitude, $longitude');
    try {
      // 1. Reverse Geocoding to get City Name, Country, State
      final Uri geocodingUri = Uri.parse(
          '$_geocodingBaseUrl?lat=$latitude&lon=$longitude&limit=1&appid=$_apiKey');
      final http.Response geoResponse = await http.get(geocodingUri);

      if (geoResponse.statusCode != 200) {
        final Map<String, dynamic> errorData = jsonDecode(geoResponse.body) as Map<String, dynamic>;
        final String errorMessage = errorData['message'] as String? ?? 'Unknown geocoding error';
        _logger.e('OpenWeatherService: Geocoding failed: ${geoResponse.statusCode}, $errorMessage');
        throw Exception('Geocoding failed: $errorMessage');
      }

      final List<dynamic> geoDataList = jsonDecode(geoResponse.body) as List<dynamic>;
      if (geoDataList.isEmpty) {
        _logger.d('OpenWeatherService: No geocoding results found for $latitude, $longitude.');
        return null;
      }
      final Map<String, dynamic> geoData = (geoDataList[0] as Map).cast<String, dynamic>();
      final String name = geoData['name'] as String;
      final String country = geoData['country'] as String;
      final String? state = geoData['state'] as String?;

      // 2. Fetch timezone offset using the weather API
      // The weather API response contains the 'timezone' field.
      final Uri weatherUri = Uri.parse(
          '$_weatherBaseUrl?lat=$latitude&lon=$longitude&appid=$_apiKey');
      final http.Response weatherResponse = await http.get(weatherUri);

      if (weatherResponse.statusCode != 200) {
        final Map<String, dynamic> errorData = jsonDecode(weatherResponse.body) as Map<String, dynamic>;
        final String errorMessage = errorData['message'] as String? ?? 'Unknown weather API error';
        _logger.e('OpenWeatherService: Weather API (for timezone) failed: ${weatherResponse.statusCode}, $errorMessage');
        throw Exception('Weather API (for timezone) failed: $errorMessage');
      }

      final Map<String, dynamic> weatherData = jsonDecode(weatherResponse.body) as Map<String, dynamic>;
      final int timezoneOffsetSeconds = weatherData['timezone'] as int;

      _logger.d('OpenWeatherService: Successfully reverse geocoded and got timezone for $name.');
      return City(
        name: name,
        country: country,
        state: state,
        latitude: latitude,
        longitude: longitude,
        timezoneOffsetSeconds: timezoneOffsetSeconds,
      );
    } catch (e) {
      _logger.e('OpenWeatherService: Error in reverseGeocode: $e', error: e);
      return null; // Return null if any part of the process fails
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