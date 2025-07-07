// lib/managers/weather_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'package:rise_and_shine/models/hourly_forecast.dart';
import 'package:rise_and_shine/models/daily_forecast.dart';
import 'package:rise_and_shine/services/open_weather_service.dart';
import 'package:rise_and_shine/managers/unit_system_manager.dart';
import 'package:rise_and_shine/utils/app_logger.dart';

// A simple model to hold combined weather data for display
class CityWeatherData {
  final City city;
  final CityLiveInfo liveInfo;
  final List<HourlyForecast> hourlyForecasts;
  final List<DailyForecast> dailyForecasts;

  CityWeatherData({
    required this.city,
    required this.liveInfo,
    required this.hourlyForecasts,
    required this.dailyForecasts,
  });

  CityWeatherData copyWith({
    City? city,
    CityLiveInfo? liveInfo,
    List<HourlyForecast>? hourlyForecasts,
    List<DailyForecast>? dailyForecasts,
  }) {
    return CityWeatherData(
      city: city ?? this.city,
      liveInfo: liveInfo ?? this.liveInfo,
      hourlyForecasts: hourlyForecasts ?? this.hourlyForecasts,
      dailyForecasts: dailyForecasts ?? this.dailyForecasts,
    );
  }
}

class WeatherManager extends ChangeNotifier {
  final OpenWeatherService _weatherService;
  final UnitSystemManager _unitSystemManager;

  // Define wind speed thresholds
  static const double _windSpeedThresholdMph = 15.0;
  static const double _windSpeedThresholdMs = 15.0 * 0.44704; // 1 mph = 0.44704 m/s

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
    logger.d('WeatherManager: Initialized. Listening to UnitSystemManager.');
  }

  void _onUnitSystemChanged() {
    logger.d('WeatherManager: Unit system changed. Recalculating and notifying weather data.');
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
    logger.d('WeatherManager: Fetching weather for ${cities.length} cities.');
    _weatherUpdateTimer?.cancel();

    // Mark all cities as loading initially
    for (final city in cities) {
      _weatherDataCache[city.hashCode] = CityWeatherData(
        city: city,
        liveInfo: CityLiveInfo.loading(city.timezoneOffsetSeconds),
        hourlyForecasts: [],
        dailyForecasts: [],
      );
    }
    _weatherDataStreamController.add(UnmodifiableMapView(_weatherDataCache));
    notifyListeners();

    final List<Future<void>> fetchFutures = [];
    for (final city in cities) {
      fetchFutures.add(_fetchAndUpdateSingleCity(city));
    }

    await Future.wait(fetchFutures);
    _weatherDataStreamController.add(UnmodifiableMapView(_weatherDataCache));
    notifyListeners();
    _startPeriodicUpdates(cities);
  }

  Future<void> _fetchAndUpdateSingleCity(City city) async {
    //logger.d('WeatherManager: _fetchAndUpdateSingleCity called for: ${city.name}');
    try {
      final Map<String, dynamic> apiResponse = await _weatherService.fetchCityTimeAndWeather(city);

      // Raw data from API is always in Metric (Celsius, m/s)
      final double rawTemperature = apiResponse['temperatureCelsius'] as double;
      final double rawFeelsLike = apiResponse['feelsLike'] as double;
      final double rawWindSpeed = apiResponse['windSpeed'] as double;
      final double? rawUvIndex = apiResponse['uvIndex'] as double?; // NEW: Get raw UV Index
      final double? rawPop = apiResponse['pop'] as double?; // NEW: Get raw POP (for current, if provided)

      // Apply unit conversion based on _unitSystemManager.isMetricUnits
      final bool isMetric = _unitSystemManager.isMetricUnits;
      final double displayTemperature = isMetric ? rawTemperature : _celsiusToFahrenheit(rawTemperature);
      final double displayFeelsLike = isMetric ? rawFeelsLike : _celsiusToFahrenheit(rawFeelsLike);
      final double displayWindSpeed = isMetric ? rawWindSpeed : _msToMph(rawWindSpeed);

      final List<HourlyForecast> rawHourlyForecasts = apiResponse['hourlyForecasts'] as List<HourlyForecast>;
      final List<DailyForecast> rawDailyForecasts = apiResponse['dailyForecasts'] as List<DailyForecast>;

      // Convert hourly forecasts
      final List<HourlyForecast> displayHourlyForecasts = rawHourlyForecasts.map((hf) {
        final double displayTemp = isMetric ? hf.temperatureCelsius : _celsiusToFahrenheit(hf.temperatureCelsius);
        final double? displayWind = hf.windSpeed != null ? (isMetric ? hf.windSpeed! : _msToMph(hf.windSpeed!)) : null;
        return hf.copyWith(
          temperatureCelsius: displayTemp,
          windSpeed: displayWind, // Converted wind speed
          pop: hf.pop, // POP is a percentage, no conversion needed
        );
      }).toList();

      // Convert daily forecasts
      final List<DailyForecast> displayDailyForecasts = rawDailyForecasts.map((df) {
        final double displayMinTemp = isMetric ? df.minTemperatureCelsius : _celsiusToFahrenheit(df.minTemperatureCelsius);
        final double displayMaxTemp = isMetric ? df.maxTemperatureCelsius : _celsiusToFahrenheit(df.maxTemperatureCelsius);
        final double? displayWind = df.windSpeed != null ? (isMetric ? df.windSpeed! : _msToMph(df.windSpeed!)) : null;
        return df.copyWith(
          minTemperatureCelsius: displayMinTemp,
          maxTemperatureCelsius: displayMaxTemp,
          windSpeed: displayWind, // Converted wind speed
          pop: df.pop, // POP is a percentage, no conversion needed
        );
      }).toList();

      final CityLiveInfo newLiveInfo = CityLiveInfo(
        currentTimeUtc: DateTime.now().toUtc(),
        timezoneOffsetSeconds: apiResponse['timezoneOffsetSeconds'] as int,
        temperatureCelsius: displayTemperature,
        feelsLike: displayFeelsLike,
        humidity: apiResponse['humidity'] as int,
        windSpeed: displayWindSpeed,
        windDirection: apiResponse['windDirection'] as String,
        condition: apiResponse['condition'] as String,
        description: apiResponse['description'] as String,
        weatherIconCode: apiResponse['weatherIconCode'] as String,
        uvIndex: rawUvIndex, // UV Index is a raw value, no conversion needed
        pop: rawPop, // POP is a raw value, no conversion needed
        isLoading: false,
        error: null,
      );

      _weatherDataCache[city.hashCode] = CityWeatherData(
        city: city,
        liveInfo: newLiveInfo,
        hourlyForecasts: displayHourlyForecasts,
        dailyForecasts: displayDailyForecasts,
      );
    } catch (e) {
      logger.e('WeatherManager: Error fetching weather for ${city.name}: $e', error: e);
      _weatherDataCache[city.hashCode] = CityWeatherData(
        city: city,
        liveInfo: CityLiveInfo(
          currentTimeUtc: DateTime.now().toUtc(),
          timezoneOffsetSeconds: city.timezoneOffsetSeconds,
          isLoading: false,
          error: e.toString(),
        ),
        hourlyForecasts: [],
        dailyForecasts: [],
      );
    }
  }

  Future<void> _fetchWeatherForCachedCities() async {
    final List<City> citiesToUpdate = _weatherDataCache.values.map((data) => data.city).toList();
    if (citiesToUpdate.isNotEmpty) {
      await fetchWeatherForCities(citiesToUpdate);
    } else {
      logger.d('WeatherManager: No cities in cache to re-fetch weather for.');
    }
  }

  // Helper to get the correct wind speed threshold based on current unit system
  double getWindSpeedThreshold() {
    return _unitSystemManager.isMetricUnits ? _windSpeedThresholdMs : _windSpeedThresholdMph;
  }

  void _startPeriodicUpdates(List<City> cities) {
    _weatherUpdateTimer?.cancel();
    if (cities.isNotEmpty) {
      _weatherUpdateTimer = Timer.periodic(const Duration(minutes: 10), (Timer timer) {
        logger.d('WeatherManager: Periodic weather update triggered.');
        _fetchWeatherForCachedCities();
      });
    } else {
      logger.d('WeatherManager: No cities to track, periodic updates not started.');
    }
  }

  void stopPeriodicUpdates() {
    _weatherUpdateTimer?.cancel();
    logger.d('WeatherManager: Stopped periodic weather updates.');
  }

  @override
  void dispose() {
    logger.d('WeatherManager: dispose called. Cancelling timers and closing stream.');
    _weatherUpdateTimer?.cancel();
    _weatherDataStreamController.close();
    _unitSystemManager.removeListener(_onUnitSystemChanged);
    super.dispose();
  }
}