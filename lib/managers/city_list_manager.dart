// lib/managers/city_list_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_display_data.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import '../services/open_weather_service.dart';
import '../services/search_cities_service.dart';
import 'package:logger/logger.dart'; // Import the logger plugin

class CityListManager extends ChangeNotifier {
  final OpenWeatherService _weatherService;
  final SearchCitiesService _searchCitiesService;

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

  // Instantiate the logger
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

  CityListManager({
    OpenWeatherService? weatherService,
    required SearchCitiesService searchCitiesService,
  })  : _weatherService = weatherService ?? OpenWeatherService(),
        _searchCitiesService = searchCitiesService {
    _initializeManager();
  }

  void _initializeManager() {
    _citiesData = [];
    _selectedCity = null;
    _isLoadingCities = false;
    _citiesFetchError = null;
    _isSearchingCities = false;
    _searchCitiesError = null;

    _citiesDataController.add(UnmodifiableListView(_citiesData));
    notifyListeners();
  }

  Future<void> fetchAvailableCities() async {
    if (kDebugMode) {
      _logger.d('CityListManager: fetchAvailableCities called.');
    }
    if (_isLoadingCities) return;

    _isLoadingCities = true;
    _citiesFetchError = null;
    notifyListeners();

    try {
      _isLoadingCities = false;
      _citiesFetchError = null;

      if (_selectedCity != null) {
        if (kDebugMode) {
          _logger.d('CityListManager: Selected city exists, fetching weather for ${_selectedCity!.name}.');
        }
        await _fetchAndUpdateSingleCity(_selectedCity!);
        _startTimers();
      } else if (_citiesData.isNotEmpty) {
        if (kDebugMode) {
          _logger.d('CityListManager: No city selected, but saved cities exist. Selecting first saved city.');
        }
        _selectedCity = _citiesData.first.city;
        _startTimers();
      } else {
        if (kDebugMode) {
          _logger.d('CityListManager: No selected city and no saved cities. Stopping timers.');
        }
        _timeUpdateTimer?.cancel();
        _weatherUpdateTimer?.cancel();
      }

      _citiesDataController.add(UnmodifiableListView(_citiesData));
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        _logger.e('CityListManager: Error in fetchAvailableCities: $e', error: e);
      }
      _isLoadingCities = false;
      _citiesFetchError = e.toString();
      _citiesData = [];
      _selectedCity = null;
      _citiesDataController.add(UnmodifiableListView(_citiesData));
      notifyListeners();
    }
  }

  Future<List<City>> searchCities(String query) async {
    if (kDebugMode) {
      _logger.d('CityListManager: searchCities called with query: "$query"');
    }
    if (query.isEmpty) {
      _isSearchingCities = false;
      _searchCitiesError = null;
      notifyListeners();
      return [];
    }

    _isSearchingCities = true;
    _searchCitiesError = null;
    notifyListeners();

    try {
      final List<City> results = await _searchCitiesService.searchCities(query);
      if (kDebugMode) {
        _logger.d('CityListManager: searchCities results count: ${results.length}');
      }
      _isSearchingCities = false;
      notifyListeners();
      return results;
    } catch (e) {
      if (kDebugMode) {
        _logger.e('CityListManager: Error in searchCities: $e', error: e);
      }
      _isSearchingCities = false;
      _searchCitiesError = e.toString();
      notifyListeners();
      return [];
    }
  }

  void selectCity(City city) {
    if (kDebugMode) {
      _logger.d('CityListManager: selectCity called for: ${city.name}');
    }
    if (_selectedCity == city) return;

    _cleanUpUnsavedUnselectedCity();

    final CityDisplayData? existingCityData = _citiesData.firstWhereOrNull((CityDisplayData data) => data.city == city);

    if (existingCityData == null) {
      if (kDebugMode) {
        _logger.d('CityListManager: City ${city.name} not in managed list, adding as unsaved.');
      }
      final CityDisplayData newCityDisplayData = CityDisplayData(
        city: city,
        liveInfo: CityLiveInfo(
          currentTimeUtc: DateTime.now().toUtc(),
          timezoneOffsetSeconds: city.timezoneOffsetSeconds,
          isLoading: true,
        ),
        isSaved: false,
      );
      _citiesData = List<CityDisplayData>.of(_citiesData)..add(newCityDisplayData);
      _selectedCity = city;
      _citiesDataController.add(UnmodifiableListView(_citiesData));
      _startTimers();
      notifyListeners();
      _fetchAndUpdateSingleCity(city);
    } else {
      if (kDebugMode) {
        _logger.d('CityListManager: City ${city.name} already in managed list, setting as selected.');
      }
      _selectedCity = city;
      notifyListeners();
    }
  }

  void addCityToSavedList(City city) {
    if (kDebugMode) {
      _logger.d('CityListManager: addCityToSavedList called for: ${city.name}');
    }
    final int index = _citiesData.indexWhere((CityDisplayData data) => data.city == city);
    if (index != -1 && !_citiesData[index].isSaved) {
      if (kDebugMode) {
        _logger.d('CityListManager: Marking ${city.name} as saved.');
      }
      final CityDisplayData updatedData = _citiesData[index].copyWith(isSaved: true);
      _citiesData = List<CityDisplayData>.of(_citiesData)..setAll(index, [updatedData]);
      _citiesDataController.add(UnmodifiableListView(_citiesData));
      notifyListeners();
    } else {
      if (kDebugMode) {
        _logger.d('CityListManager: ${city.name} not found or already saved. No action taken.');
      }
    }
  }

  bool isCitySaved(City city) {
    final bool saved = _citiesData.any((CityDisplayData data) => data.city == city && data.isSaved);
    if (kDebugMode) {
      _logger.d('CityListManager: isCitySaved for ${city.name}: $saved');
    }
    return saved;
  }

  void clearSelectedCity() {
    if (kDebugMode) {
      _logger.d('CityListManager: clearSelectedCity called.');
    }
    _cleanUpUnsavedUnselectedCity();
    _selectedCity = null;
    notifyListeners();
    _timeUpdateTimer?.cancel();
    _weatherUpdateTimer?.cancel();
    _citiesDataController.add(UnmodifiableListView(_citiesData));
  }

  void _cleanUpUnsavedUnselectedCity() {
    if (kDebugMode) {
      _logger.d('CityListManager: _cleanUpUnsavedUnselectedCity called. Current cities count: ${_citiesData.length}');
    }
    final List<CityDisplayData> currentCities = List<CityDisplayData>.of(_citiesData);
    final int initialCount = currentCities.length;
    currentCities.removeWhere((CityDisplayData data) => !data.isSaved && data.city != _selectedCity);
    if (currentCities.length != initialCount) {
      if (kDebugMode) {
        _logger.d('CityListManager: Removed ${initialCount - currentCities.length} unsaved, unselected cities.');
      }
      _citiesData = List<CityDisplayData>.unmodifiable(currentCities);
      _citiesDataController.add(_citiesData);
    } else {
      if (kDebugMode) {
        _logger.d('CityListManager: No unsaved, unselected cities to remove.');
      }
    }
  }

  void _startTimers() {
    if (kDebugMode) {
      _logger.d('CityListManager: _startTimers called.');
    }
    _timeUpdateTimer?.cancel();
    _weatherUpdateTimer?.cancel();

    if (_citiesData.isNotEmpty) {
      _fetchWeatherForAllCities();
    } else {
      if (kDebugMode) {
        _logger.d('CityListManager: No cities in _citiesData, not starting weather fetch timer.');
      }
    }

    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _updateTimeForAllCities();
    });

    _weatherUpdateTimer = Timer.periodic(const Duration(minutes: 5), (Timer timer) {
      _fetchWeatherForAllCities();
    });
  }

  void _updateTimeForAllCities() {
    if (_citiesData.isEmpty) return;

    final DateTime nowUtc = DateTime.now().toUtc();
    final List<CityDisplayData> updatedList = _citiesData.map((CityDisplayData cityData) {
      // Use Value() wrapper for nullable fields when updating time, to preserve weather data
      final CityLiveInfo newLiveInfo = cityData.liveInfo.copyWith(
        currentTimeUtc: nowUtc,
        // Explicitly pass existing weather data using Value() to prevent nulling out
        temperatureCelsius: Value(cityData.liveInfo.temperatureCelsius),
        feelsLike: Value(cityData.liveInfo.feelsLike),
        humidity: Value(cityData.liveInfo.humidity),
        windSpeed: Value(cityData.liveInfo.windSpeed),
        windDirection: Value(cityData.liveInfo.windDirection),
        condition: Value(cityData.liveInfo.condition),
        description: Value(cityData.liveInfo.description),
        weatherIconCode: Value(cityData.liveInfo.weatherIconCode),
        error: Value(cityData.liveInfo.error),
        isLoading: cityData.liveInfo.isLoading, // Keep existing isLoading state
      );
      return cityData.copyWith(liveInfo: newLiveInfo);
    }).toList();

    _citiesData = List<CityDisplayData>.unmodifiable(updatedList);
    _citiesDataController.add(_citiesData);
  }

  Future<void> _fetchWeatherForAllCities() async {
    if (kDebugMode) {
      _logger.d('CityListManager: _fetchWeatherForAllCities called. Cities count: ${_citiesData.length}');
    }
    if (_citiesData.isEmpty) return;

    final List<Future<void>> fetchFutures = [];

    _citiesData = _citiesData.map((CityDisplayData cityData) {
      return cityData.copyWith(
        liveInfo: cityData.liveInfo.copyWith(isLoading: true, error: Value(null)), // Use Value(null) to explicitly clear error
      );
    }).toList();
    _citiesDataController.add(UnmodifiableListView(_citiesData));

    for (int i = 0; i < _citiesData.length; i++) {
      final CityDisplayData cityData = _citiesData[i];
      fetchFutures.add(_fetchAndUpdateSingleCity(cityData.city));
    }

    await Future.wait(fetchFutures);
    _citiesDataController.add(UnmodifiableListView(_citiesData));
  }

  Future<void> _fetchAndUpdateSingleCity(City city) async {
    if (kDebugMode) {
      _logger.d('CityListManager: _fetchAndUpdateSingleCity called for: ${city.name}');
    }
    try {
      final Map<String, dynamic> apiResponse = await _weatherService.fetchCityTimeAndWeather(city);
      if (kDebugMode) {
        _logger.d('CityListManager: Weather data received for ${city.name}.');
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
        error: null, // No error on success
      );

      final int index = _citiesData.indexWhere((CityDisplayData c) => c.city == city);
      if (index != -1) {
        final CityDisplayData updatedCityDisplayData = _citiesData[index].copyWith(liveInfo: newLiveInfo);
        _citiesData = List<CityDisplayData>.of(_citiesData)..setAll(index, [updatedCityDisplayData]);
        _citiesDataController.add(UnmodifiableListView(_citiesData));
      }
    } catch (e) {
      if (kDebugMode) {
        _logger.e('CityListManager: Error fetching weather for ${city.name}: $e', error: e);
      }
      final int index = _citiesData.indexWhere((CityDisplayData c) => c.city == city);
      if (index != -1) {
        final CityLiveInfo errorLiveInfo = _citiesData[index].liveInfo.copyWith(
          isLoading: false,
          // FIX: Wrap the error string in Value() as per sentinel pattern
          error: Value(e.toString()),
          // FIX: Explicitly set weather data to null using Value(null) on error
          temperatureCelsius: Value(null),
          feelsLike: Value(null),
          humidity: Value(null),
          windSpeed: Value(null),
          windDirection: Value(null),
          condition: Value(null),
          description: Value(null),
          weatherIconCode: Value(null),
        );
        final CityDisplayData updatedCityDisplayData = _citiesData[index].copyWith(liveInfo: errorLiveInfo);
        _citiesData = List<CityDisplayData>.of(_citiesData)..setAll(index, [updatedCityDisplayData]);
        _citiesDataController.add(UnmodifiableListView(_citiesData));
      }
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      _logger.d('CityListManager: dispose called.');
    }
    _timeUpdateTimer?.cancel();
    _weatherUpdateTimer?.cancel();
    _citiesDataController.close();
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