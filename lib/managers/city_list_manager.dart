// lib/managers/city_list_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_display_data.dart';
import '../services/open_weather_api.dart'; // This import refers to the file, not the class name

class CityListManager extends ChangeNotifier {
  final OpenWeatherService _weatherService; // Corrected type: OpenWeatherService

  List<CityDisplayData> _citiesData = [];

  City? _selectedCity;

  final StreamController<List<CityDisplayData>> _citiesDataController =
  StreamController<List<CityDisplayData>>.broadcast();

  Stream<List<CityDisplayData>> get citiesDataStream => _citiesDataController.stream;

  City? get selectedCity => _selectedCity;

  bool _isLoadingCities = false;
  bool get isLoadingCities => _isLoadingCities;

  String? _citiesFetchError;
  String? get citiesFetchError => _citiesFetchError;

  Timer? _timeUpdateTimer;
  Timer? _weatherUpdateTimer;

  CityListManager({OpenWeatherService? weatherService}) // Corrected type: OpenWeatherService
      : _weatherService = weatherService ?? OpenWeatherService() { // Corrected type: OpenWeatherService
    _initializeManager();
  }

  void _initializeManager() {
    _citiesData = [];
    _selectedCity = null;
    _isLoadingCities = false;
    _citiesFetchError = null;

    _citiesDataController.add(UnmodifiableListView(_citiesData));
    notifyListeners();
  }

  Future<void> fetchAvailableCities() async {
    if (_isLoadingCities) return;

    _isLoadingCities = true;
    _citiesFetchError = null;
    notifyListeners();

    try {
      _isLoadingCities = false;
      _citiesFetchError = null;

      if (_citiesData.isNotEmpty) {
        _selectedCity = _citiesData.first.city;
        _startTimers();
      } else {
        _timeUpdateTimer?.cancel();
        _weatherUpdateTimer?.cancel();
      }

      _citiesDataController.add(UnmodifiableListView(_citiesData));
      notifyListeners();
    } catch (e) {
      _isLoadingCities = false;
      _citiesFetchError = e.toString();
      _citiesData = [];
      _selectedCity = null;
      _citiesDataController.add(UnmodifiableListView(_citiesData));
      notifyListeners();
    }
  }

  void selectCity(City city) {
    if (_selectedCity != city) {
      _selectedCity = city;
      notifyListeners();
    }
  }

  CityDisplayData? getSelectedCityDisplayData() {
    if (_selectedCity == null) return null;
    return _citiesData.firstWhereOrNull((cityData) => cityData.city == _selectedCity);
  }

  void _startTimers() {
    _timeUpdateTimer?.cancel();
    _weatherUpdateTimer?.cancel();

    _fetchWeatherForAllCities();

    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeForAllCities();
    });

    _weatherUpdateTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _fetchWeatherForAllCities();
    });
  }

  void _updateTimeForAllCities() {
    if (_citiesData.isEmpty) return;

    final nowUtc = DateTime.now().toUtc();
    final updatedList = _citiesData.map((cityData) {
      final newLiveInfo = cityData.liveInfo.copyWith(currentTimeUtc: nowUtc);
      return cityData.copyWith(liveInfo: newLiveInfo);
    }).toList();

    _citiesData = List.unmodifiable(updatedList);
    _citiesDataController.add(_citiesData);
  }

  Future<void> _fetchWeatherForAllCities() async {
    if (_citiesData.isEmpty) return;

    final List<Future<void>> fetchFutures = [];

    _citiesData = _citiesData.map((cityData) {
      return cityData.copyWith(
        liveInfo: cityData.liveInfo.copyWith(isLoading: true, error: null),
      );
    }).toList();
    _citiesDataController.add(UnmodifiableListView(_citiesData));

    for (int i = 0; i < _citiesData.length; i++) {
      final cityData = _citiesData[i];
      fetchFutures.add(_fetchAndUpdateSingleCity(cityData.city));
    }

    await Future.wait(fetchFutures);
    _citiesDataController.add(UnmodifiableListView(_citiesData));
  }

  Future<void> _fetchAndUpdateSingleCity(City city) async {
    try {
      final apiResponse = await _weatherService.fetchCityTimeAndWeather(city);

      final newLiveInfo = _citiesData
          .firstWhere((c) => c.city == city)
          .liveInfo
          .copyWith(
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

      final index = _citiesData.indexWhere((c) => c.city == city);
      if (index != -1) {
        final updatedCityDisplayData = _citiesData[index].copyWith(liveInfo: newLiveInfo);
        _citiesData = List.of(_citiesData)..setAll(index, [updatedCityDisplayData]);
        _citiesDataController.add(UnmodifiableListView(_citiesData));
      }
    } catch (e) {
      final index = _citiesData.indexWhere((c) => c.city == city);
      if (index != -1) {
        final errorLiveInfo = _citiesData[index].liveInfo.copyWith(
          isLoading: false,
          error: e.toString(),
          temperatureCelsius: null,
          feelsLike: null,
          humidity: null,
          windSpeed: null,
          windDirection: null,
          condition: null,
          description: null,
          weatherIconCode: null,
        );
        final updatedCityDisplayData = _citiesData[index].copyWith(liveInfo: errorLiveInfo);
        _citiesData = List.of(_citiesData)..setAll(index, [updatedCityDisplayData]);
        _citiesDataController.add(UnmodifiableListView(_citiesData));
      }
    }
  }

  @override
  void dispose() {
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

final CityListManager cityListManager = CityListManager();