// lib/services/open_weather_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rise_and_shine/models/city.dart';
import 'package:logger/logger.dart'; // Import the logger plugin
import 'package:flutter/foundation.dart'; // For kDebugMode

class OpenWeatherService {
  static const String _apiKey = '4a2b73e379f5b7f36dd6e51e291e987e';
  static const String _weatherBaseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  // Instantiate the logger
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0, // No method calls to be displayed
      errorMethodCount: 5, // Number of method calls if stacktrace is provided
      lineLength: 120, // Width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print emojis for log messages
      printTime: true, // Should each log message contain a timestamp
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
          // FIX: Changed to use named argument 'error' for the exception object
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