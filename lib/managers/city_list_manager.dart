// lib/managers/city_list_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_display_data.dart'; // FIX: Import CityDisplayData from its dedicated file
import 'package:rise_and_shine/services/search_cities_service.dart';
import 'package:rise_and_shine/services/location_service.dart';
import 'package:rise_and_shine/utils/app_logger.dart';

// REMOVED: The duplicate CityDisplayData class definition was here.


class CityListManager extends ChangeNotifier {
  static const String _citiesBoxName = 'savedCitiesBox';
  late Box _citiesBox;

  final SearchCitiesService _searchCitiesService;
  final LocationService _locationService;

  List<CityDisplayData> _citiesData = []; // Internal list of CityDisplayData

  // Public getter for the list of actual City objects
  List<City> get allCities => UnmodifiableListView(_citiesData.map((data) => data.city).toList());

  City? _selectedCity;
  City? get selectedCity => _selectedCity;

  bool _isSearchingCities = false;
  bool get isSearchingCities => _isSearchingCities;

  String? _searchCitiesError;
  String? get searchCitiesError => _searchCitiesError;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  CityListManager({
    required SearchCitiesService searchCitiesService,
    required LocationService locationService,
  })  : _searchCitiesService = searchCitiesService,
        _locationService = locationService {
    _initializeManager();
  }

  Future<void> _initializeManager() async {
    _citiesData = [];
    _selectedCity = null;
    _isSearchingCities = false;
    _searchCitiesError = null;

    //if (kDebugMode) {
    //  logger.d('CityListManager: _initializeManager started.');
   // }

    try {
      if (!Hive.isBoxOpen(_citiesBoxName)) {
        _citiesBox = await Hive.openBox(_citiesBoxName);
        //logger.d('CityListManager: Hive box "$_citiesBoxName" opened.');
      } else {
        _citiesBox = Hive.box(_citiesBoxName);
        //logger.d('CityListManager: Hive box "$_citiesBoxName" already open.');
      }

      _loadCitiesFromHive();

      City? currentLocationCity;
      try {
        currentLocationCity = await _locationService.getCurrentCityLocation();
        //if (currentLocationCity != null) {
         // logger.d('CityListManager: Detected current location: ${currentLocationCity.name}, ${currentLocationCity.country}');
        //} else {
        //  logger.d('CityListManager: Could not detect current location via LocationService.');
        //}
      } catch (e) {
        logger.e('CityListManager: Error getting current location from LocationService: $e', error: e);
        currentLocationCity = null;
      }

      if (currentLocationCity != null && !_citiesData.any((data) => data.city == currentLocationCity)) {
        final CityDisplayData newCityDisplayData = CityDisplayData(
          city: currentLocationCity,
          isSaved: false,
        );
        _citiesData.insert(0, newCityDisplayData);
        _selectedCity = currentLocationCity;
        //logger.d('CityListManager: Added current location as selected city: ${currentLocationCity.name}.');
      } else if (currentLocationCity != null) {
        final existingData = _citiesData.firstWhereOrNull((data) => data.city == currentLocationCity);
        if (existingData != null) {
          _selectedCity = existingData.city;
          //logger.d('CityListManager: Current location ${currentLocationCity.name} already in list, setting as selected.');
        }
      }

      if (_selectedCity == null && _citiesData.isNotEmpty) {
        _selectedCity = _citiesData.first.city;
        logger.d('CityListManager: No current location, selected first loaded city: ${_selectedCity!.name}');
      } else if (_selectedCity == null && _citiesData.isEmpty) {
        logger.d('CityListManager: No saved cities and no current location detected. App starts with no city selected.');
      }

      //if (kDebugMode) {
     //   logger.d('CityListManager: Final _citiesData after initialization: ${_citiesData.length} cities.');
      //  for (var data in _citiesData) {
      //    logger.d('  - Final list: ${data.city.name} (Saved: ${data.isSaved}, Selected: ${data.city == _selectedCity})');
      //  }
      //}

      _initCompleter.complete();
      notifyListeners();
    } catch (e) {
      logger.e('CityListManager: Error initializing Hive or loading cities: $e', error: e);
      _searchCitiesError = 'Failed to initialize app data: ${e.toString()}';
      _initCompleter.completeError(e);
      notifyListeners();
      rethrow;
    }
  }

  void _loadCitiesFromHive() {
    final List<dynamic>? savedJsonList = _citiesBox.get('savedCities');
    if (savedJsonList != null) {
      //logger.d('CityListManager: Found ${savedJsonList.length} cities in Hive.');
      for (final dynamic jsonItem in savedJsonList) {
        try {
          final Map<String, dynamic> cityMap = Map<String, dynamic>.from(jsonItem);
          final CityDisplayData cityDisplayData = CityDisplayData.fromJson(cityMap);
          _citiesData.add(cityDisplayData);
        } catch (e) {
          logger.e('CityListManager: Error parsing saved city from Hive: $e, data: $jsonItem', error: e);
        }
      }
    }
    //else {
    //  logger.d('CityListManager: No saved cities found in Hive.');
    //}
    //logger.d('CityListManager: After _loadCitiesFromHive, final _citiesData count: ${_citiesData.length}');
  }

  Future<void> _saveCitiesToHive() async {
    logger.d('CityListManager: Saving cities to Hive.');
    final List<Map<String, dynamic>> citiesToSave = _citiesData
        .where((data) => data.isSaved)
        .map((data) => data.toJson())
        .toList();

    try {
      await _citiesBox.put('savedCities', citiesToSave);
      logger.d('CityListManager: Successfully saved ${citiesToSave.length} cities to Hive.');
    } catch (e) {
      logger.e('CityListManager: Error saving cities to Hive: $e', error: e);
    }
  }

  Future<List<City>> searchCities(String query) async {
    if (kDebugMode) {
      logger.d('CityListManager: searchCities called with query: "$query"');
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
        logger.d('CityListManager: searchCities results count: ${results.length}');
      }
      _isSearchingCities = false;
      notifyListeners();
      return results;
    } catch (e) {
      if (kDebugMode) {
        logger.e('CityListManager: Error in searchCities: $e', error: e);
      }
      _isSearchingCities = false;
      _searchCitiesError = e.toString();
      notifyListeners();
      return [];
    }
  }

  void selectCity(City city) {
    if (kDebugMode) {
      logger.d('CityListManager: selectCity called for: ${city.name}');
    }
    if (_selectedCity == city) return;

    _cleanUpUnsavedUnselectedCity();

    final CityDisplayData? existingCityData = _citiesData.firstWhereOrNull((data) => data.city == city);
    if (existingCityData == null) {
      final newCityDisplayData = CityDisplayData(city: city, isSaved: false);
      _citiesData.add(newCityDisplayData);
      logger.d('CityListManager: Added new unsaved city ${city.name} to list for selection.');
    }

    _selectedCity = city;
    notifyListeners();
  }

  void addCityToSavedList(City city) {
    if (kDebugMode) {
      logger.d('CityListManager: addCityToSavedList called for: ${city.name}.');
    }
    final int index = _citiesData.indexWhere((CityDisplayData data) => data.city == city);
    if (index != -1) {
      if (!_citiesData[index].isSaved) {
        _citiesData[index].isSaved = true;
        logger.d('CityListManager: Marked ${city.name} as saved.');
        _saveCitiesToHive();
        notifyListeners();
      } else {
        logger.d('CityListManager: ${city.name} is already saved. No action taken.');
      }
    } else {
      final newCityDisplayData = CityDisplayData(city: city, isSaved: true);
      _citiesData.add(newCityDisplayData);
      logger.d('CityListManager: Added ${city.name} as a new saved city.');
      _saveCitiesToHive();
      notifyListeners();
    }
  }

  bool isCitySaved(City city) {
    return _citiesData.any((data) => data.city == city && data.isSaved);
  }

  void removeCity(City cityToRemove) {
    logger.d('CityListManager: removeCity called for: ${cityToRemove.name}');
    final int initialCount = _citiesData.length;
    _citiesData.removeWhere((data) => data.city == cityToRemove);

    if (_citiesData.length != initialCount) {
      logger.d('CityListManager: Successfully removed ${cityToRemove.name}.');
      _saveCitiesToHive();

      if (_selectedCity == cityToRemove) {
        logger.d('CityListManager: Removed city was selected. Updating selected city.');
        if (_citiesData.isNotEmpty) {
          _selectedCity = _citiesData.first.city;
          logger.d('CityListManager: New selected city: ${_selectedCity!.name}');
        } else {
          _selectedCity = null;
          logger.d('CityListManager: No cities left, selected city set to null.');
        }
      }
      notifyListeners();
    } else {
      logger.d('CityListManager: City ${cityToRemove.name} not found in list, no action taken.');
    }
  }

  void clearSelectedCity() {
    logger.d('CityListManager: clearSelectedCity called.');
    _cleanUpUnsavedUnselectedCity();
    _selectedCity = null;
    notifyListeners();
  }

  void _cleanUpUnsavedUnselectedCity() {
    if (kDebugMode) {
      logger.d('CityListManager: _cleanUpUnsavedUnselectedCity called. Initial cities count: ${_citiesData.length}');
      for (var data in _citiesData) {
        logger.d('  - Before cleanup: ${data.city.name} (Saved: ${data.isSaved}, Selected: ${data.city == _selectedCity})');
      }
    }

    final int initialCount = _citiesData.length;
    _citiesData.removeWhere((data) => !data.isSaved && data.city != _selectedCity);
    if (_citiesData.length != initialCount) {
      if (kDebugMode) {
        logger.d('CityListManager: Removed ${initialCount - _citiesData.length} unsaved, unselected cities.');
      }
      _saveCitiesToHive();
    } else {
      if (kDebugMode) {
        logger.d('CityListManager: No unsaved, unselected cities to remove.');
      }
    }
    if (kDebugMode) {
      logger.d('CityListManager: After _cleanUpUnsavedUnselectedCity, final cities count: ${_citiesData.length}');
      for (var data in _citiesData) {
        logger.d('  - After cleanup: ${data.city.name} (Saved: ${data.isSaved}, Selected: ${data.city == _selectedCity})');
      }
    }
  }

  @override
  void dispose() {
    logger.d('CityListManager: dispose called. Closing cities box.');
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