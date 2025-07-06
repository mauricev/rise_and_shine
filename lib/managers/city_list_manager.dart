// lib/managers/city_list_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_display_data.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'package:rise_and_shine/models/hourly_forecast.dart';
import 'package:rise_and_shine/models/daily_forecast.dart';
import '../services/open_weather_service.dart';
import '../services/search_cities_service.dart';
import '../services/location_service.dart';
// REMOVED: import 'package:logger/logger.dart'; // No longer needed here
import 'package:rise_and_shine/utils/app_logger.dart'; // NEW: Import the global logger
import 'package:hive_ce_flutter/adapters.dart';


class CityListManager extends ChangeNotifier {
  static const String _citiesBoxName = 'savedCitiesBox';
  late Box _citiesBox;

  final OpenWeatherService _weatherService;
  final SearchCitiesService _searchCitiesService;
  final LocationService _locationService;

  List<CityDisplayData> _citiesData = [];

  List<CityDisplayData> get allCitiesDisplayData => UnmodifiableListView(_citiesData);

  City? _selectedCity;

  final StreamController<List<CityDisplayData>> _citiesDataController =
  StreamController<List<CityDisplayData>>.broadcast();

  Stream<List<CityDisplayData>> get citiesDataStream => _citiesDataController.stream;

  City? get selectedCity => _selectedCity;

  bool _isLoadingCities = false;
  bool get isLoadingCities => _isLoadingCities;

  String? _citiesFetchError;
  String? get citiesFetchError => _citiesFetchError;

  bool _isSearchingCities = false;
  bool get isSearchingCities => _isSearchingCities;

  String? _searchCitiesError;
  String? get searchCitiesError => _searchCitiesError;

  Timer? _timeUpdateTimer;
  Timer? _weatherUpdateTimer;

  // REMOVED: final Logger _logger = Logger(...); // No longer declared here

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  factory CityListManager() {
    final OpenWeatherService weatherService = OpenWeatherService();
    final SearchCitiesService searchCitiesService = SearchCitiesService();
    final LocationService locationService = LocationService(openWeatherService: weatherService);

    final manager = CityListManager._internal(
      weatherService: weatherService,
      searchCitiesService: searchCitiesService,
      locationService: locationService,
    );

    manager._initializeManager().then((_) {
      manager._initCompleter.complete();
      logger.d('CityListManager: Initialization completed successfully.'); // Use global logger
    }).catchError((e) {
      manager._initCompleter.completeError(e);
      logger.e('CityListManager: Initialization failed: $e', error: e); // Use global logger
    });

    return manager;
  }

  CityListManager._internal({
    required OpenWeatherService weatherService,
    required SearchCitiesService searchCitiesService,
    required LocationService locationService,
  })  : _weatherService = weatherService,
        _searchCitiesService = searchCitiesService,
        _locationService = locationService;


  Future<void> _initializeManager() async {
    _citiesData = [];
    _selectedCity = null;
    _isLoadingCities = false;
    _citiesFetchError = null;
    _isSearchingCities = false;
    _searchCitiesError = null;

    if (kDebugMode) {
      logger.d('CityListManager: _initializeManager started.'); // Use global logger
    }

    try {
      if (!Hive.isBoxOpen(_citiesBoxName)) {
        _citiesBox = await Hive.openBox(_citiesBoxName);
        logger.d('CityListManager: Hive box "$_citiesBoxName" opened.'); // Use global logger
      } else {
        _citiesBox = Hive.box(_citiesBoxName);
        logger.d('CityListManager: Hive box "$_citiesBoxName" already open.'); // Use global logger
      }

      City? currentLocationCity;
      try {
        currentLocationCity = await _locationService.getCurrentCityLocation();
        if (currentLocationCity != null) {
          logger.d('CityListManager: Detected current location: ${currentLocationCity.name}, ${currentLocationCity.country}'); // Use global logger
        } else {
          logger.d('CityListManager: Could not detect current location via LocationService.'); // Use global logger
        }
      } catch (e) {
        logger.e('CityListManager: Error getting current location from LocationService: $e', error: e); // Use global logger
        currentLocationCity = null;
      }

      if (currentLocationCity != null) {
        logger.d('CityListManager: Attempting to use current location: ${currentLocationCity.name}'); // Use global logger
        final CityDisplayData newCityDisplayData = CityDisplayData(
          city: currentLocationCity,
          liveInfo: CityLiveInfo(
            currentTimeUtc: DateTime.now().toUtc(),
            timezoneOffsetSeconds: currentLocationCity.timezoneOffsetSeconds,
            isLoading: true,
          ),
          isSaved: false,
          hourlyForecasts: [],
          dailyForecasts: [],
        );
        _citiesData = List<CityDisplayData>.of(_citiesData)..insert(0, newCityDisplayData);
        _selectedCity = currentLocationCity;
        logger.d('CityListManager: Added current location as selected city: ${currentLocationCity.name}.'); // Use global logger
      }

      _loadCitiesFromHive();

      if (_selectedCity == null && _citiesData.isNotEmpty) {
        _selectedCity = _citiesData.first.city;
        logger.d('CityListManager: No current location, selected first loaded city: ${_selectedCity!.name}'); // Use global logger
      } else if (_selectedCity == null && _citiesData.isEmpty) {
        logger.d('CityListManager: No saved cities and no current location detected. App starts with no city selected.'); // Use global logger
      }


      if (kDebugMode) {
        logger.d('CityListManager: Final _citiesData before adding to controller: ${_citiesData.length} cities.'); // Use global logger
        for (var data in _citiesData) {
          logger.d('  - Final list: ${data.city.name} (Saved: ${data.isSaved}, Selected: ${data.city == _selectedCity})'); // Use global logger
        }
      }

      _citiesDataController.add(UnmodifiableListView(_citiesData));
      if (hasListeners) notifyListeners();
    } catch (e) {
      logger.e('CityListManager: Error initializing Hive or loading cities: $e', error: e); // Use global logger
      _citiesFetchError = 'Failed to initialize app data: ${e.toString()}';
      if (hasListeners) notifyListeners();
      rethrow;
    }
  }

  void _loadCitiesFromHive() {
    _citiesData = _citiesData.where((data) => data.city == _selectedCity && !data.isSaved).toList();
    if (kDebugMode) {
      logger.d('CityListManager: Loading cities from Hive. Current _citiesData count before load: ${_citiesData.length}'); // Use global logger
    }
    final List<dynamic>? savedJsonList = _citiesBox.get('savedCities');

    if (savedJsonList != null) {
      if (kDebugMode) {
        logger.d('CityListManager: Found ${savedJsonList.length} cities in Hive.'); // Use global logger
      }
      for (final dynamic jsonItem in savedJsonList) {
        try {
          final Map<String, dynamic> cityMap = Map<String, dynamic>.from(jsonItem);
          final CityDisplayData cityDisplayData = CityDisplayData.fromJson(cityMap);
          if (!_citiesData.any((existingData) => existingData.city == cityDisplayData.city)) {
            _citiesData.add(cityDisplayData);
          }
        } catch (e) {
          logger.e('CityListManager: Error parsing saved city from Hive: $e, data: $jsonItem', error: e); // Use global logger
        }
      }
    } else {
      logger.d('CityListManager: No saved cities found in Hive.'); // Use global logger
    }
    if (kDebugMode) {
      logger.d('CityListManager: After _loadCitiesFromHive, final _citiesData count: ${_citiesData.length}'); // Use global logger
    }
  }

  Future<void> _saveCitiesToHive() async {
    if (kDebugMode) {
      logger.d('CityListManager: Saving cities to Hive.'); // Use global logger
    }
    final List<Map<String, dynamic>> citiesToSave = _citiesData
        .where((data) => data.isSaved)
        .map((data) => data.toJson())
        .toList();

    try {
      await _citiesBox.put('savedCities', citiesToSave);
      logger.d('CityListManager: Successfully saved ${citiesToSave.length} cities to Hive.'); // Use global logger
    } catch (e) {
      logger.e('CityListManager: Error saving cities to Hive: $e', error: e); // Use global logger
    }
  }

  void removeCity(City cityToRemove) {
    logger.d('CityListManager: removeCity called for: ${cityToRemove.name}'); // Use global logger
    final int initialCount = _citiesData.length;
    _citiesData.removeWhere((data) => data.city == cityToRemove);

    if (_citiesData.length != initialCount) {
      logger.d('CityListManager: Successfully removed ${cityToRemove.name}.'); // Use global logger
      _saveCitiesToHive();

      if (_selectedCity == cityToRemove) {
        logger.d('CityListManager: Removed city was selected. Updating selected city.'); // Use global logger
        if (_citiesData.isNotEmpty) {
          _selectedCity = _citiesData.first.city;
          logger.d('CityListManager: New selected city: ${_selectedCity!.name}'); // Use global logger
        } else {
          _selectedCity = null;
          logger.d('CityListManager: No cities left, selected city set to null.'); // Use global logger
        }
      }
      _citiesDataController.add(UnmodifiableListView(_citiesData));
      if (hasListeners) notifyListeners();
    } else {
      logger.d('CityListManager: City ${cityToRemove.name} not found in list, no action taken.'); // Use global logger
    }
  }

  Future<void> fetchAvailableCities() async {
    if (kDebugMode) {
      logger.d('CityListManager: fetchAvailableCities called. (After initial Hive load)'); // Use global logger
    }
    if (_isLoadingCities) {
      logger.d('CityListManager: fetchAvailableCities: Already loading, returning.'); // Use global logger
      return;
    }

    _isLoadingCities = true;
    _citiesFetchError = null;
    if (hasListeners) notifyListeners();

    try {
      if (_selectedCity != null || _citiesData.isNotEmpty) {
        logger.d('CityListManager: fetchAvailableCities: Cities available, starting timers.'); // Use global logger
        _startTimers();
      } else {
        logger.d('CityListManager: fetchAvailableCities: No selected city and no saved cities. Not starting timers.'); // Use global logger
        _timeUpdateTimer?.cancel();
        _weatherUpdateTimer?.cancel();
      }

      _isLoadingCities = false;
      _citiesDataController.add(UnmodifiableListView(_citiesData));
      if (hasListeners) notifyListeners();
      logger.d('CityListManager: fetchAvailableCities: Completed.'); // Use global logger
    } catch (e) {
      logger.e('CityListManager: Error in fetchAvailableCities: $e', error: e); // Use global logger
      _isLoadingCities = false;
      _citiesFetchError = e.toString();
      _citiesData = [];
      _selectedCity = null;
      _citiesDataController.add(UnmodifiableListView(_citiesData));
      if (hasListeners) notifyListeners();
    }
  }

  Future<List<City>> searchCities(String query) async {
    if (kDebugMode) {
      logger.d('CityListManager: searchCities called with query: "$query"'); // Use global logger
    }
    if (query.isEmpty) {
      _isSearchingCities = false;
      _searchCitiesError = null;
      if (hasListeners) notifyListeners();
      return [];
    }

    _isSearchingCities = true;
    _searchCitiesError = null;
    if (hasListeners) notifyListeners();

    try {
      final List<City> results = await _searchCitiesService.searchCities(query);
      if (kDebugMode) {
        logger.d('CityListManager: searchCities results count: ${results.length}'); // Use global logger
      }
      _isSearchingCities = false;
      if (hasListeners) notifyListeners();
      return results;
    } catch (e) {
      if (kDebugMode) {
        logger.e('CityListManager: Error in searchCities: $e', error: e); // Use global logger
      }
      _isSearchingCities = false;
      _searchCitiesError = e.toString();
      if (hasListeners) notifyListeners();
      return [];
    }
  }

  void selectCity(City city) {
    if (kDebugMode) {
      logger.d('CityListManager: selectCity called for: ${city.name}'); // Use global logger
    }
    if (_selectedCity == city) return;

    _cleanUpUnsavedUnselectedCity();

    final CityDisplayData? existingCityData = _citiesData.firstWhereOrNull((CityDisplayData data) => data.city == city);

    if (existingCityData == null) {
      if (kDebugMode) {
        logger.d('CityListManager: City ${city.name} not in managed list, adding as unsaved.'); // Use global logger
      }
      final CityDisplayData newCityDisplayData = CityDisplayData(
        city: city,
        liveInfo: CityLiveInfo(
          currentTimeUtc: DateTime.now().toUtc(),
          timezoneOffsetSeconds: city.timezoneOffsetSeconds,
          isLoading: true,
        ),
        isSaved: false,
        hourlyForecasts: [],
        dailyForecasts: [],
      );
      _citiesData = List<CityDisplayData>.of(_citiesData)..add(newCityDisplayData);
      _selectedCity = city;
      _citiesDataController.add(UnmodifiableListView(_citiesData));
      _startTimers();
      if (hasListeners) notifyListeners();
      _fetchAndUpdateSingleCity(city);
    } else {
      if (kDebugMode) {
        logger.d('CityListManager: City ${city.name} already in managed list, setting as selected.'); // Use global logger
      }
      _selectedCity = city;
      if (hasListeners) notifyListeners();
      _fetchAndUpdateSingleCity(city);
    }
  }

  void addCityToSavedList(City city) {
    if (kDebugMode) {
      logger.d('CityListManager: addCityToSavedList called for: ${city.name}.'); // Use global logger
    }
    final int index = _citiesData.indexWhere((CityDisplayData data) => data.city == city);
    if (index != -1 && !_citiesData[index].isSaved) {
      if (kDebugMode) {
        logger.d('CityListManager: Marking ${city.name} as saved.'); // Use global logger
      }
      final CityDisplayData updatedData = _citiesData[index].copyWith(isSaved: true);
      _citiesData = List<CityDisplayData>.of(_citiesData)..setAll(index, [updatedData]);
      _citiesDataController.add(UnmodifiableListView(_citiesData));
      if (hasListeners) notifyListeners();
      _saveCitiesToHive();
    } else {
      if (kDebugMode) {
        logger.d('CityListManager: ${city.name} already saved or not found in current managed list. No action taken.'); // Use global logger
      }
    }
  }

  bool isCitySaved(City city) {
    final bool saved = _citiesData.any((CityDisplayData data) => data.city == city && data.isSaved);
    return saved;
  }

  void clearSelectedCity() {
    if (kDebugMode) {
      logger.d('CityListManager: clearSelectedCity called.'); // Use global logger
    }
    _cleanUpUnsavedUnselectedCity();
    _selectedCity = null;
    if (hasListeners) notifyListeners();
    _timeUpdateTimer?.cancel();
    _weatherUpdateTimer?.cancel();
    _citiesDataController.add(UnmodifiableListView(_citiesData));
  }

  void _cleanUpUnsavedUnselectedCity() {
    if (kDebugMode) {
      logger.d('CityListManager: _cleanUpUnsavedUnselectedCity called. Initial cities count: ${_citiesData.length}'); // Use global logger
      for (var data in _citiesData) {
        logger.d('  - Before cleanup: ${data.city.name} (Saved: ${data.isSaved}, Selected: ${data.city == _selectedCity})'); // Use global logger
      }
    }

    final List<CityDisplayData> currentCities = List<CityDisplayData>.of(_citiesData);
    final int initialCount = currentCities.length;
    currentCities.removeWhere((CityDisplayData data) => !data.isSaved && data.city != _selectedCity);
    if (currentCities.length != initialCount) {
      if (kDebugMode) {
        logger.d('CityListManager: Removed ${initialCount - currentCities.length} unsaved, unselected cities.'); // Use global logger
      }
      _citiesData = List<CityDisplayData>.unmodifiable(currentCities);
      _citiesDataController.add(_citiesData);
      _saveCitiesToHive();
    } else {
      if (kDebugMode) {
        logger.d('CityListManager: No unsaved, unselected cities to remove.'); // Use global logger
      }
    }
    if (kDebugMode) {
      logger.d('CityListManager: After _cleanUpUnsavedUnselectedCity, final cities count: ${_citiesData.length}'); // Use global logger
      for (var data in _citiesData) {
        logger.d('  - After cleanup: ${data.city.name} (Saved: ${data.isSaved}, Selected: ${data.city == _selectedCity})'); // Use global logger
      }
    }
  }

  void _startTimers() {
    if (kDebugMode) {
      logger.d('CityListManager: _startTimers called.'); // Use global logger
    }
    _timeUpdateTimer?.cancel();
    _weatherUpdateTimer?.cancel();

    if (_citiesData.isNotEmpty) {
      logger.d('CityListManager: _startTimers: _citiesData is not empty, initiating _fetchWeatherForAllCities.'); // Use global logger
      _fetchWeatherForAllCities();
    } else {
      logger.d('CityListManager: _startTimers: _citiesData is empty, skipping initial weather fetch.'); // Use global logger
    }

    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _updateTimeForAllCities();
    });

    _weatherUpdateTimer = Timer.periodic(const Duration(minutes: 10), (Timer timer) {
      _fetchWeatherForAllCities();
    });
  }

  void _updateTimeForAllCities() {
    if (_citiesData.isEmpty) return;

    final DateTime nowUtc = DateTime.now().toUtc();
    final List<CityDisplayData> updatedList = _citiesData.map((CityDisplayData cityData) {
      final List<HourlyForecast>? updatedHourlyForecasts = cityData.hourlyForecasts?.map((forecast) {
        return forecast;
      }).toList();

      final List<DailyForecast>? updatedDailyForecasts = cityData.dailyForecasts?.map((forecast) {
        return forecast;
      }).toList();


      final CityLiveInfo newLiveInfo = cityData.liveInfo.copyWith(
        currentTimeUtc: nowUtc,
        timezoneOffsetSeconds: cityData.liveInfo.timezoneOffsetSeconds,
        temperatureCelsius: Value(cityData.liveInfo.temperatureCelsius),
        feelsLike: Value(cityData.liveInfo.feelsLike),
        humidity: Value(cityData.liveInfo.humidity),
        windSpeed: Value(cityData.liveInfo.windSpeed),
        windDirection: Value(cityData.liveInfo.windDirection),
        condition: Value(cityData.liveInfo.condition),
        description: Value(cityData.liveInfo.description),
        weatherIconCode: Value(cityData.liveInfo.weatherIconCode),
        error: Value(cityData.liveInfo.error),
        isLoading: cityData.liveInfo.isLoading,
      );
      return cityData.copyWith(
        liveInfo: newLiveInfo,
        hourlyForecasts: Value(updatedHourlyForecasts),
        dailyForecasts: Value(updatedDailyForecasts),
      );
    }).toList();

    _citiesData = List<CityDisplayData>.unmodifiable(updatedList);
    _citiesDataController.add(UnmodifiableListView(_citiesData));
  }

  Future<void> _fetchWeatherForAllCities() async {
    if (kDebugMode) {
      logger.d('CityListManager: _fetchWeatherForAllCities called. Cities count: ${_citiesData.length}'); // Use global logger
    }
    if (_citiesData.isEmpty) {
      logger.d('CityListManager: _citiesData is empty, skipping weather fetch for all cities.'); // Use global logger
      return;
    }

    final List<Future<void>> fetchFutures = [];

    _citiesData = _citiesData.map((CityDisplayData cityData) {
      return cityData.copyWith(
        liveInfo: cityData.liveInfo.copyWith(isLoading: true, error: Value(null)),
        hourlyForecasts: Value(null),
        dailyForecasts: Value(null),
      );
    }).toList();
    _citiesDataController.add(UnmodifiableListView(_citiesData));

    for (int i = 0; i < _citiesData.length; i++) {
      final CityDisplayData cityData = _citiesData[i];
      fetchFutures.add(_fetchAndUpdateSingleCity(cityData.city));
    }

    await Future.wait(fetchFutures);
    _citiesDataController.add(UnmodifiableListView(_citiesData));
    logger.d('CityListManager: _fetchWeatherForAllCities: All fetches completed.'); // Use global logger
  }

  Future<void> _fetchAndUpdateSingleCity(City city) async {
    if (kDebugMode) {
      logger.d('CityListManager: _fetchAndUpdateSingleCity called for: ${city.name}'); // Use global logger
    }
    try {
      final Map<String, dynamic> apiResponse = await _weatherService.fetchCityTimeAndWeather(city);
      if (kDebugMode) {
        logger.d('CityListManager: Weather data received for ${city.name}.'); // Use global logger
      }

      final CityLiveInfo newLiveInfo = CityLiveInfo(
        currentTimeUtc: DateTime.now().toUtc(),
        timezoneOffsetSeconds: apiResponse['timezoneOffsetSeconds'] as int,
        temperatureCelsius: apiResponse['temperatureCelsius'] as double,
        feelsLike: apiResponse['feelsLike'] as double,
        humidity: apiResponse['humidity'] as int,
        windSpeed: apiResponse['windSpeed'] as double,
        windDirection: apiResponse['windDirection'] as String,
        condition: apiResponse['condition'] as String,
        description: apiResponse['description'] as String,
        weatherIconCode: apiResponse['weatherIconCode'] as String,
        isLoading: false,
        error: null,
      );

      final List<HourlyForecast> hourlyForecasts = apiResponse['hourlyForecasts'] as List<HourlyForecast>;
      final List<DailyForecast> dailyForecasts = apiResponse['dailyForecasts'] as List<DailyForecast>;

      final int index = _citiesData.indexWhere((CityDisplayData c) => c.city == city);
      if (index != -1) {
        final CityDisplayData updatedCityDisplayData = _citiesData[index].copyWith(
          liveInfo: newLiveInfo,
          hourlyForecasts: Value(hourlyForecasts),
          dailyForecasts: Value(dailyForecasts),
        );
        _citiesData = List<CityDisplayData>.of(_citiesData)..setAll(index, [updatedCityDisplayData]);
      }
    } catch (e) {
      if (kDebugMode) {
        logger.e('CityListManager: Error fetching weather for ${city.name}: $e', error: e); // Use global logger
      }
      final int index = _citiesData.indexWhere((CityDisplayData c) => c.city == city);
      if (index != -1) {
        final CityLiveInfo errorLiveInfo = _citiesData[index].liveInfo.copyWith(
          isLoading: false,
          error: Value(e.toString()),
          temperatureCelsius: Value(null),
          feelsLike: Value(null),
          humidity: Value(null),
          windSpeed: Value(null),
          windDirection: Value(null),
          condition: Value(null),
          description: Value(null),
          weatherIconCode: Value(null),
        );
        final CityDisplayData updatedCityDisplayData = _citiesData[index].copyWith(
          liveInfo: errorLiveInfo,
          hourlyForecasts: Value(null),
          dailyForecasts: Value(null),
        );
        _citiesData = List<CityDisplayData>.of(_citiesData)..setAll(index, [updatedCityDisplayData]);
      }
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      logger.d('CityListManager: dispose called.'); // Use global logger
    }
    _timeUpdateTimer?.cancel();
    _weatherUpdateTimer?.cancel();
    _citiesDataController.close();
    _citiesBox.close();
    super.dispose();
  }
}

extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}