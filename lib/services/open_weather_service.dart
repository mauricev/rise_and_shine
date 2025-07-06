// lib/services/open_weather_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/hourly_forecast.dart';
import 'package:rise_and_shine/models/daily_forecast.dart';
// REMOVED: import 'package:logger/logger.dart'; // No longer needed here
import 'package:rise_and_shine/utils/app_logger.dart'; // NEW: Import the global logger
import 'package:flutter/foundation.dart';

class OpenWeatherService {
  static const String _apiKey = '4a2b73e379f5b7f36dd6e51e291e987e';
  static const String _oneCallBaseUrl = 'https://api.openweathermap.org/data/3.0/onecall';
  static const String _geocodingBaseUrl = 'https://api.openweathermap.org/geo/1.0/reverse';

  // REMOVED: final Logger _logger = Logger(...); // No longer declared here

  Future<Map<String, dynamic>> fetchCityTimeAndWeather(City city) async {
    final Uri uri = Uri.parse(
        '$_oneCallBaseUrl?lat=${city.latitude}&lon=${city.longitude}&exclude=minutely,alerts&appid=$_apiKey&units=metric');

    if (kDebugMode) {
      logger.d('OpenWeatherService: Fetching weather from One Call API 3.0: $uri'); // Use global logger
      logger.d('OpenWeatherService: Using API Key: $_apiKey'); // Use global logger
    }

    final http.Response response = await http.get(uri);

    if (kDebugMode) {
      logger.d('OpenWeatherService: Response status code: ${response.statusCode}'); // Use global logger
      logger.d('OpenWeatherService: Response body: ${response.body}'); // Use global logger
    }

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;

      try {
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
        final int timezoneOffset = data['timezone_offset'] as int;

        List<HourlyForecast> hourlyForecasts = [];
        if (data['hourly'] != null) {
          final List<dynamic> hourlyDataList = data['hourly'] as List<dynamic>;
          for (int i = 0; i < hourlyDataList.length && i < 12; i++) {
            hourlyForecasts.add(HourlyForecast.fromJson(Map<String, dynamic>.from(hourlyDataList[i])));
          }
          if (kDebugMode) {
            logger.d('OpenWeatherService: Parsed ${hourlyForecasts.length} hourly forecasts.'); // Use global logger
          }
        }

        List<DailyForecast> dailyForecasts = [];
        if (data['daily'] != null) {
          final List<dynamic> dailyDataList = data['daily'] as List<dynamic>;
          for (int i = 0; i < dailyDataList.length && i < 8; i++) {
            dailyForecasts.add(DailyForecast.fromJson(Map<String, dynamic>.from(dailyDataList[i])));
          }
          if (kDebugMode) {
            logger.d('OpenWeatherService: Parsed ${dailyForecasts.length} daily forecasts.'); // Use global logger
          }
        }


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
          'hourlyForecasts': hourlyForecasts,
          'dailyForecasts': dailyForecasts,
        };

        if (kDebugMode) {
          logger.d('OpenWeatherService: Successfully parsed weather data: $parsedData'); // Use global logger
        }
        return parsedData;
      } catch (e) {
        if (kDebugMode) {
          logger.e('OpenWeatherService: Error parsing weather data for ${city.name}: $e', error: e); // Use global logger
          logger.e('OpenWeatherService: Raw data that caused parsing error: ${response.body}'); // Use global logger
        }
        throw Exception('Failed to parse weather data for ${city.name}: $e');
      }
    } else {
      final Map<String, dynamic> errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final String errorMessage = errorData['message'] as String? ?? 'Unknown error';
      if (kDebugMode) {
        logger.e('OpenWeatherService: Failed to load weather data for ${city.name}. Status: ${response.statusCode}, Message: $errorMessage'); // Use global logger
      }
      throw Exception('Failed to load weather data for ${city.name}: $errorMessage (Status: ${response.statusCode})');
    }
  }

  Future<City?> reverseGeocode(double latitude, double longitude) async {
    final Uri uri = Uri.parse(
        '$_geocodingBaseUrl?lat=$latitude&lon=$longitude&limit=1&appid=$_apiKey');

    if (kDebugMode) {
      logger.d('OpenWeatherService: Reverse geocoding from: $uri'); // Use global logger
    }

    final http.Response response = await http.get(uri);

    if (kDebugMode) {
      logger.d('OpenWeatherService: Reverse geocoding response status code: ${response.statusCode}'); // Use global logger
      logger.d('OpenWeatherService: Reverse geocoding response body: ${response.body}'); // Use global logger
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      if (data.isEmpty) {
        logger.d('OpenWeatherService: No geocoding results found for $latitude, $longitude.'); // Use global logger
        return null;
      }

      try {
        final Map<String, dynamic> cityData = Map<String, dynamic>.from(data[0]); // Use Map.from
        final String name = cityData['name'] as String;
        final String country = cityData['country'] as String;
        final String? state = cityData['state'] as String?;

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
          logger.e('OpenWeatherService: Failed to get timezone for $name. Status: ${timezoneResponse.statusCode}, Message: $errorMessage'); // Use global logger
          throw Exception('Failed to get timezone for $name: $errorMessage');
        }
      } catch (e) {
        logger.e('OpenWeatherService: Error parsing geocoding data for $latitude, $longitude: $e', error: e); // Use global logger
        throw Exception('Failed to parse geocoding data: ${e.toString()}');
      }
    } else {
      final Map<String, dynamic> errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final String errorMessage = errorData['message'] as String? ?? 'Unknown error';
      logger.e('OpenWeatherService: Failed to reverse geocode $latitude, $longitude. Status: ${response.statusCode}, Message: $errorMessage'); // Use global logger
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