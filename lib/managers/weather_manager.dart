// lib/managers/weather_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'package:rise_and_shine/models/hourly_forecast.dart';
import 'package:rise_and_shine/models/daily_forecast.dart';
import 'package:rise_and_shine/models/weather_alert.dart';
import 'package:rise_and_shine/models/city_weather_data.dart';
import 'package:rise_and_shine/services/open_weather_service.dart';
import 'package:rise_and_shine/managers/unit_system_manager.dart';
import 'package:rise_and_shine/utils/app_logger.dart'; // Keep this import for error logging

class WeatherManager extends ChangeNotifier {
  final OpenWeatherService _weatherService;
  final UnitSystemManager _unitSystemManager;

  static const double _windSpeedThresholdMph = 15.0;
  static const double _windSpeedThresholdMs = 15.0 * 0.44704;

  final Map<int, CityWeatherData> _weatherDataCache = {};

  final StreamController<Map<int, CityWeatherData>> _weatherDataStreamController =
  StreamController<Map<int, CityWeatherData>>.broadcast();

  Stream<Map<int, CityWeatherData>> get weatherDataStream => _weatherDataStreamController.stream;

  Timer? _weatherUpdateTimer;

  WeatherManager({
    required OpenWeatherService weatherService,
    required UnitSystemManager unitSystemManager,
  })  : _weatherService = weatherService,
        _unitSystemManager = unitSystemManager {
    _unitSystemManager.addListener(_onUnitSystemChanged);
    // logger.d('WeatherManager: Initialized. Listening to UnitSystemManager.'); // Removed
  }

  void _onUnitSystemChanged() {
    // logger.d('WeatherManager: Unit system changed. Recalculating and notifying weather data.'); // Removed
    _fetchWeatherForCachedCities();
  }

  CityWeatherData? getWeatherForCity(City city) {
    return _weatherDataCache[city.hashCode];
  }

  double _celsiusToFahrenheit(double celsius) {
    return (celsius * 9 / 5) + 32;
  }

  double _msToMph(double ms) {
    return ms * 2.23694;
  }

  Future<void> fetchWeatherForCities(List<City> cities) async {
    // logger.d('WeatherManager: fetchWeatherForCities called for ${cities.map((c) => c.name).join(', ')}'); // Removed
    _weatherUpdateTimer?.cancel();

    for (final city in cities) {
      // Set loading state immediately in cache and notify listeners
      _weatherDataCache[city.hashCode] = CityWeatherData(
        city: city,
        liveInfo: CityLiveInfo.loading(),
        hourlyForecasts: _weatherDataCache[city.hashCode]?.hourlyForecasts ?? [],
        dailyForecasts: _weatherDataCache[city.hashCode]?.dailyForecasts ?? [],
        alerts: _weatherDataCache[city.hashCode]?.alerts ?? [],
      );
    }
    _weatherDataStreamController.add(UnmodifiableMapView(_weatherDataCache));
    notifyListeners(); // Notify after setting loading states

    final List<Future<void>> fetchFutures = [];
    for (final city in cities) {
      fetchFutures.add(_fetchAndUpdateSingleCity(city));
    }

    await Future.wait(fetchFutures);
    // logger.d('WeatherManager: All city weather fetches completed.'); // Removed
    _startPeriodicUpdates(cities);
  }

  Future<void> _fetchAndUpdateSingleCity(City city) async {
    // logger.d('WeatherManager: Attempting to fetch weather for city: ${city.name}'); // Removed
    try {
      final Map<String, dynamic> apiResponse = await _weatherService.fetchCityTimeAndWeather(city);
      // logger.d('WeatherManager: Raw API response received for ${city.name}. Keys: ${apiResponse.keys.join(', ')}'); // Removed
      // logger.d('WeatherManager: Full Raw API response for ${city.name}: $apiResponse'); // Removed

      // Safely extract values, providing defaults if null
      final double rawTemperature = (apiResponse['temperatureCelsius'] as double?) ?? 0.0;
      final double rawFeelsLike = (apiResponse['feelsLike'] as double?) ?? 0.0;
      final double rawWindSpeed = (apiResponse['windSpeed'] as double?) ?? 0.0;
      final double? rawUvIndex = apiResponse['uvIndex'] as double?;

      final int timezoneOffsetSeconds = (apiResponse['timezoneOffsetSeconds'] as int?) ?? 0;
      final int sunriseTimeEpoch = (apiResponse['sunriseTimeEpoch'] as int?) ?? 0;
      final int sunsetTimeEpoch = (apiResponse['sunsetTimeEpoch'] as int?) ?? 0;
      String weatherIconCode = (apiResponse['weatherIconCode'] as String?) ?? '01d'; // Default to clear day

      // FIX: Determine isDayStatus based on weatherIconCode suffix if available
      // If the API provides an 'isDay' boolean, we can use it, but the icon code is more reliable.
      bool isDayStatus;
      if (weatherIconCode.endsWith('d')) {
        isDayStatus = true;
      } else if (weatherIconCode.endsWith('n')) {
        isDayStatus = false;
      } else {
        // Fallback to API's 'isDay' or default to true if icon code is ambiguous
        isDayStatus = (apiResponse['isDay'] as bool?) ?? true;
        logger.w('WeatherManager: Ambiguous weatherIconCode "$weatherIconCode" for ${city.name}. Falling back to API isDay: $isDayStatus');
      }


      final String description = (apiResponse['description'] as String?) ?? 'N/A';
      final int humidity = (apiResponse['humidity'] as int?) ?? 0;
      final String windDirection = (apiResponse['windDirection'] as String?) ?? 'N/A';

      final List<HourlyForecast> rawHourlyForecasts = (apiResponse['hourlyForecasts'] as List<HourlyForecast>?) ?? [];
      final List<DailyForecast> rawDailyForecasts = (apiResponse['dailyForecasts'] as List<DailyForecast>?) ?? [];
      final List<WeatherAlert> alerts = (apiResponse['alerts'] as List<WeatherAlert>?) ?? [];


      final bool isMetric = _unitSystemManager.isMetricUnits;
      final double displayTemperature = isMetric ? rawTemperature : _celsiusToFahrenheit(rawTemperature);
      final double displayFeelsLike = isMetric ? rawFeelsLike : _celsiusToFahrenheit(rawFeelsLike);
      final double displayWindSpeed = isMetric ? rawWindSpeed : _msToMph(rawWindSpeed);

      final List<HourlyForecast> displayHourlyForecasts = rawHourlyForecasts.map((hf) {
        final double displayTemp = isMetric ? hf.temperatureCelsius : _celsiusToFahrenheit(hf.temperatureCelsius);
        final double? displayWind = hf.windSpeed != null ? (isMetric ? hf.windSpeed! : _msToMph(hf.windSpeed!)) : null;
        return hf.copyWith(
          temperatureCelsius: displayTemp,
          windSpeed: displayWind,
          pop: hf.pop,
        );
      }).toList();

      final List<DailyForecast> displayDailyForecasts = rawDailyForecasts.map((df) {
        final double displayMinTemp = isMetric ? df.minTemperatureCelsius : _celsiusToFahrenheit(df.minTemperatureCelsius);
        final double displayMaxTemp = isMetric ? df.maxTemperatureCelsius : _celsiusToFahrenheit(df.maxTemperatureCelsius);
        final double? displayWind = df.windSpeed != null ? (isMetric ? df.windSpeed! : _msToMph(df.windSpeed!)) : null;
        return df.copyWith(
          minTemperatureCelsius: displayMinTemp,
          maxTemperatureCelsius: displayMaxTemp,
          windSpeed: displayWind,
          pop: df.pop,
        );
      }).toList();

      final CityLiveInfo newLiveInfo = CityLiveInfo(
        timezoneOffsetSeconds: timezoneOffsetSeconds,
        temperatureCelsius: displayTemperature,
        feelsLike: displayFeelsLike,
        humidity: humidity,
        windSpeed: displayWindSpeed,
        windDirection: windDirection,
        description: description,
        weatherIconCode: weatherIconCode,
        uvIndex: rawUvIndex,
        isLoading: false, // Set to false on successful fetch
        error: null,
        sunriseTimeEpoch: sunriseTimeEpoch,
        sunsetTimeEpoch: sunsetTimeEpoch,
        isDay: isDayStatus, // Use the derived isDayStatus
      );

      _weatherDataCache[city.hashCode] = CityWeatherData(
        city: city,
        liveInfo: newLiveInfo,
        hourlyForecasts: displayHourlyForecasts,
        dailyForecasts: displayDailyForecasts,
        alerts: alerts,
      );
      // IMPORTANT FIX: Notify listeners immediately after a single city's data is updated
      _weatherDataStreamController.add(UnmodifiableMapView(_weatherDataCache));
      notifyListeners();
      // logger.d('WeatherManager: Successfully processed and updated cache for ${city.name}. Live Info: $newLiveInfo'); // Removed
    } catch (e, stack) {
      logger.e('WeatherManager: Error fetching weather for ${city.name}: $e', error: e, stackTrace: stack);
      _weatherDataCache[city.hashCode] = CityWeatherData(
        city: city,
        liveInfo: CityLiveInfo.error(e.toString()),
        hourlyForecasts: _weatherDataCache[city.hashCode]?.hourlyForecasts ?? [],
        dailyForecasts: _weatherDataCache[city.hashCode]?.dailyForecasts ?? [],
        alerts: _weatherDataCache[city.hashCode]?.alerts ?? [],
      );
      // Notify on error as well to update UI with error state
      _weatherDataStreamController.add(UnmodifiableMapView(_weatherDataCache));
      notifyListeners();
    }
  }

  Future<void> _fetchWeatherForCachedCities() async {
    final List<City> citiesToUpdate = _weatherDataCache.values.map((data) => data.city).toList();
    if (citiesToUpdate.isNotEmpty) {
      // logger.d('WeatherManager: _fetchWeatherForCachedCities: Re-fetching weather for ${citiesToUpdate.length} cached cities.'); // Removed
      await fetchWeatherForCities(citiesToUpdate);
    } else {
      // logger.d('WeatherManager: No cities in cache to re-fetch weather for.'); // Removed
    }
  }

  double getWindSpeedThreshold() {
    return _unitSystemManager.isMetricUnits ? _windSpeedThresholdMs : _windSpeedThresholdMph;
  }

  void _startPeriodicUpdates(List<City> cities) {
    _weatherUpdateTimer?.cancel();
    if (cities.isNotEmpty) {
      _weatherUpdateTimer = Timer.periodic(const Duration(minutes: 10), (Timer timer) {
        // logger.d('WeatherManager: Periodic weather update triggered.'); // Removed
        _fetchWeatherForCachedCities();
      });
    } else {
      // logger.d('WeatherManager: No cities to track, periodic updates not started.'); // Removed
    }
  }

  void stopPeriodicUpdates() {
    _weatherUpdateTimer?.cancel();
    // logger.d('WeatherManager: Stopped periodic weather updates.'); // Removed
  }

  @override
  void dispose() {
    // logger.d('WeatherManager: dispose called. Cancelling timers and closing stream.'); // Removed
    _weatherUpdateTimer?.cancel();
    _weatherDataStreamController.close();
    _unitSystemManager.removeListener(_onUnitSystemChanged);
    super.dispose();
  }
}