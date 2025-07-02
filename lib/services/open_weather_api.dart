// lib/services/open_weather_api.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rise_and_shine/models/city.dart';

class OpenWeatherService {
  static const String _apiKey = '4a2b73e379f5b7f36dd6e51e291e987e';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  Future<Map<String, dynamic>> fetchCityTimeAndWeather(City city) async {
    final Uri uri = Uri.parse( // Added type annotation
        '$_baseUrl?lat=${city.latitude}&lon=${city.longitude}&appid=$_apiKey&units=metric');

    final http.Response response = await http.get(uri); // Added type annotation

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>; // Added type annotation and cast

      final double temperature = (data['main']['temp'] as num).toDouble();
      final double feelsLike = (data['main']['feels_like'] as num).toDouble();
      final int humidity = data['main']['humidity'] as int;
      final double windSpeed = (data['wind']['speed'] as num).toDouble();
      final int? windDegrees = data['wind']['deg'] as int?;
      final String condition = data['weather'][0]['main'] as String;
      final String description = data['weather'][0]['description'] as String;
      final int timezoneOffset = data['timezone'] as int;

      return {
        'temperatureCelsius': temperature,
        'feelsLike': feelsLike,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'windDirection': _degreesToCardinal(windDegrees),
        'condition': condition,
        'description': description,
        'timezoneOffsetSeconds': timezoneOffset,
      };
    } else {
      final Map<String, dynamic> errorData = jsonDecode(response.body) as Map<String, dynamic>; // Added type annotation and cast
      throw Exception('Failed to load weather data for ${city.name}: ${errorData['message']} (Status: ${response.statusCode})');
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