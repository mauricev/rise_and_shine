// lib/managers/city_list_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_display_data.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import '../services/open_weather_service.dart';
import '../services/search_cities_service.dart';
import '../services/location_service.dart';
import 'package:logger/logger.dart';
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

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  // FIX: Removed the duplicate unnamed constructor.
  // The factory constructor below is now the primary way to create CityListManager.

  // Factory constructor to ensure services are instantiated once and correctly wired
  // before the manager's initialization process begins.
  factory CityListManager() {
    final OpenWeatherService weatherService = OpenWeatherService();
    final SearchCitiesService searchCitiesService = SearchCitiesService();
    final LocationService locationService = LocationService(openWeatherService: weatherService); // Use the single instance

    final manager = CityListManager._internal(
      weatherService: weatherService,
      searchCitiesService: searchCitiesService,
      locationService: locationService,
    );

    // Start the asynchronous initialization process for the manager
    manager._initializeManager().then((_) {
      manager._initCompleter.complete();
      manager._logger.d('CityListManager: Initialization completed successfully.');
    }).catchError((e) {
      manager._initCompleter.completeError(e);
      manager._logger.e('CityListManager: Initialization failed: $e', error: e);
    });

    return manager;
  }

  // Private constructor to allow instantiation with pre-created services.
  // This is called by the factory constructor.
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

    try {
      if (!Hive.isBoxOpen(_citiesBoxName)) {
        _citiesBox = await Hive.openBox(_citiesBoxName);
        _logger.d('CityListManager: Hive box "$_citiesBoxName" opened.');
      } else {
        _citiesBox = Hive.box(_citiesBoxName);
        _logger.d('CityListManager: Hive box "$_citiesBoxName" already open.');
      }

      _loadCitiesFromHive();

      City? currentLocationCity;
      try {
        currentLocationCity = await _locationService.getCurrentCityLocation();
        if (currentLocationCity != null) {
          _logger.d('CityListManager: Detected current location: ${currentLocationCity.name}');
        } else {
          _logger.d('CityListManager: Could not detect current location.');
        }
      } catch (e) {
        _logger.e('CityListManager: Error getting current location: $e', error: e);
        currentLocationCity = null;
      }

      if (_citiesData.isNotEmpty) {
        _selectedCity = _citiesData.first.city;
        _logger.d('CityListManager: Selected first loaded city: ${_selectedCity!.name}');
      } else if (currentLocationCity != null) {
        _logger.d('CityListManager: No saved cities, selecting current location: ${currentLocationCity.name}');

        final CityDisplayData? existingCityData = _citiesData.firstWhereOrNull(
                (data) => data.city.name == currentLocationCity!.name && data.city.country == currentLocationCity.country);

        if (existingCityData != null) {
          _selectedCity = existingCityData.city;
          _logger.d('CityListManager: Current location matches existing saved city: ${existingCityData.city.name}. Selecting it.');
        } else {
          final CityDisplayData newCityDisplayData = CityDisplayData(
            city: currentLocationCity,
            liveInfo: CityLiveInfo(
              currentTimeUtc: DateTime.now().toUtc(),
              timezoneOffsetSeconds: currentLocationCity.timezoneOffsetSeconds,
              isLoading: true,
            ),
            isSaved: false,
          );
          _citiesData = List<CityDisplayData>.of(_citiesData)..insert(0, newCityDisplayData);
          _selectedCity = currentLocationCity;
          _logger.d('CityListManager: Added current location as unsaved selected city: ${currentLocationCity.name}');
        }
      } else {
        _logger.d('CityListManager: No saved cities and no current location detected. App starts with no city selected.');
      }

      _citiesDataController.add(UnmodifiableListView(_citiesData));
      if (hasListeners) notifyListeners();
    } catch (e) {
      _logger.e('CityListManager: Error initializing Hive or loading cities: $e', error: e);
      _citiesFetchError = 'Failed to initialize app data: ${e.toString()}';
      if (hasListeners) notifyListeners();
      rethrow;
    }
  }

  void _loadCitiesFromHive() {
    _citiesData = [];
    if (kDebugMode) {
      _logger.d('CityListManager: Loading cities from Hive.');
    }
    final List<dynamic>? savedJsonList = _citiesBox.get('savedCities');

    if (savedJsonList != null) {
      if (kDebugMode) {
        _logger.d('CityListManager: Found ${savedJsonList.length} cities in Hive.');
      }
      for (final dynamic jsonItem in savedJsonList) {
        try {
          final Map<String, dynamic> cityMap = (jsonItem as Map).cast<String, dynamic>();
          final CityDisplayData cityDisplayData = CityDisplayData.fromJson(cityMap);
          _citiesData.add(cityDisplayData);
        } catch (e) {
          _logger.e('CityListManager: Error parsing saved city from Hive: $e, data: $jsonItem', error: e);
        }
      }
    } else {
      _logger.d('CityListManager: No saved cities found in Hive.');
    }
  }

  Future<void> _saveCitiesToHive() async {
    if (kDebugMode) {
      _logger.d('CityListManager: Saving cities to Hive.');
    }
    final List<Map<String, dynamic>> citiesToSave = _citiesData
        .where((data) => data.isSaved)
        .map((data) => data.toJson())
        .toList();

    try {
      await _citiesBox.put('savedCities', citiesToSave);
      _logger.d('CityListManager: Successfully saved ${citiesToSave.length} cities to Hive.');
    } catch (e) {
      _logger.e('CityListManager: Error saving cities to Hive: $e', error: e);
    }
  }

  Future<void> fetchAvailableCities() async {
    if (kDebugMode) {
      _logger.d('CityListManager: fetchAvailableCities called. (After initial Hive load)');
    }
    if (_isLoadingCities) {
      _logger.d('CityListManager: fetchAvailableCities: Already loading, returning.');
      return;
    }

    _isLoadingCities = true;
    _citiesFetchError = null;
    if (hasListeners) notifyListeners();

    try {
      if (_selectedCity != null || _citiesData.isNotEmpty) {
        _logger.d('CityListManager: fetchAvailableCities: Cities available, starting timers.');
        _startTimers();
      } else {
        _logger.d('CityListManager: fetchAvailableCities: No selected city and no saved cities. Not starting timers.');
        _timeUpdateTimer?.cancel();
        _weatherUpdateTimer?.cancel();
      }

      _isLoadingCities = false;
      _citiesDataController.add(UnmodifiableListView(_citiesData));
      if (hasListeners) notifyListeners();
      _logger.d('CityListManager: fetchAvailableCities: Completed.');
    } catch (e) {
      _logger.e('CityListManager: Error in fetchAvailableCities: $e', error: e);
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
      _logger.d('CityListManager: searchCities called with query: "$query"');
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
        _logger.d('CityListManager: searchCities results count: ${results.length}');
      }
      _isSearchingCities = false;
      if (hasListeners) notifyListeners();
      return results;
    } catch (e) {
      if (kDebugMode) {
        _logger.e('CityListManager: Error in searchCities: $e', error: e);
      }
      _isSearchingCities = false;
      _searchCitiesError = e.toString();
      if (hasListeners) notifyListeners();
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
      if (hasListeners) notifyListeners();
      _fetchAndUpdateSingleCity(city);
    } else {
      if (kDebugMode) {
        _logger.d('CityListManager: City ${city.name} already in managed list, setting as selected.');
      }
      _selectedCity = city;
      if (hasListeners) notifyListeners();
      _fetchAndUpdateSingleCity(city);
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
      if (hasListeners) notifyListeners();
      _saveCitiesToHive();
    } else {
      if (kDebugMode) {
        _logger.d('CityListManager: ${city.name} already saved or not found in current managed list. No action taken.');
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
    if (hasListeners) notifyListeners();
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
    // Remove cities that are NOT saved and are NOT the currently selected city
    currentCities.removeWhere((CityDisplayData data) => !data.isSaved && data.city != _selectedCity);
    if (currentCities.length != initialCount) {
      if (kDebugMode) {
        _logger.d('CityListManager: Removed ${initialCount - currentCities.length} unsaved, unselected cities.');
      }
      _citiesData = List<CityDisplayData>.unmodifiable(currentCities);
      _citiesDataController.add(_citiesData);
      _saveCitiesToHive();
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
      _logger.d('CityListManager: _citiesData is empty, skipping initial weather fetch.');
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
    _logger.d('CityListManager: _updateTimeForAllCities called.');

    final DateTime nowUtc = DateTime.now().toUtc();
    final List<CityDisplayData> updatedList = _citiesData.map((CityDisplayData cityData) {
      final CityLiveInfo newLiveInfo = cityData.liveInfo.copyWith(
        currentTimeUtc: nowUtc,
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
      return cityData.copyWith(liveInfo: newLiveInfo);
    }).toList();

    _citiesData = List<CityDisplayData>.unmodifiable(updatedList);
    _citiesDataController.add(UnmodifiableListView(_citiesData));
  }

  Future<void> _fetchWeatherForAllCities() async {
    if (kDebugMode) {
      _logger.d('CityListManager: _fetchWeatherForAllCities called. Cities count: ${_citiesData.length}');
    }
    if (_citiesData.isEmpty) {
      _logger.d('CityListManager: _citiesData is empty, skipping weather fetch for all cities.');
      return;
    }

    final List<Future<void>> fetchFutures = [];

    _citiesData = _citiesData.map((CityDisplayData cityData) {
      return cityData.copyWith(
        liveInfo: cityData.liveInfo.copyWith(isLoading: true, error: Value(null)),
      );
    }).toList();
    _citiesDataController.add(UnmodifiableListView(_citiesData));

    for (int i = 0; i < _citiesData.length; i++) {
      final CityDisplayData cityData = _citiesData[i];
      fetchFutures.add(_fetchAndUpdateSingleCity(cityData.city));
    }

    await Future.wait(fetchFutures);
    _citiesDataController.add(UnmodifiableListView(_citiesData));
    _logger.d('CityListManager: _fetchWeatherForAllCities: All fetches completed.');
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
        error: null,
      );

      final int index = _citiesData.indexWhere((CityDisplayData c) => c.city == city);
      if (index != -1) {
        final CityDisplayData updatedCityDisplayData = _citiesData[index].copyWith(liveInfo: newLiveInfo);
        _citiesData = List<CityDisplayData>.of(_citiesData)..setAll(index, [updatedCityDisplayData]);
      }
    } catch (e) {
      if (kDebugMode) {
        _logger.e('CityListManager: Error fetching weather for ${city.name}: $e', error: e);
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
        final CityDisplayData updatedCityDisplayData = _citiesData[index].copyWith(liveInfo: errorLiveInfo);
        _citiesData = List<CityDisplayData>.of(_citiesData)..setAll(index, [updatedCityDisplayData]);
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