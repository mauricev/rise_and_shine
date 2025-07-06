// lib/providers/app_managers_provider.dart

import 'package:flutter/material.dart';
// REMOVED: import 'package:provider/provider.dart'; // FIX: Removed as per instruction
import 'package:rise_and_shine/managers/city_list_manager.dart';
import 'package:rise_and_shine/managers/unit_system_manager.dart';
import 'package:rise_and_shine/managers/weather_manager.dart';
import 'package:rise_and_shine/services/open_weather_service.dart';
import 'package:rise_and_shine/services/search_cities_service.dart';
import 'package:rise_and_shine/services/location_service.dart';
import 'package:rise_and_shine/utils/app_logger.dart';

// NEW: Define a custom InheritedWidget to provide managers down the tree
class AppManagers extends InheritedWidget {
  final CityListManager cityListManager;
  final UnitSystemManager unitSystemManager;
  final WeatherManager weatherManager;

  const AppManagers({
    super.key,
    required this.cityListManager,
    required this.unitSystemManager,
    required this.weatherManager,
    required super.child,
  });

  // Method to get the instance of AppManagers from context
  static AppManagers of(BuildContext context) {
    final AppManagers? result = context.dependOnInheritedWidgetOfExactType<AppManagers>();
    assert(result != null, 'No AppManagers found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(covariant AppManagers oldWidget) {
    // This widget doesn't hold mutable state that changes its own content,
    // but its children depend on the managers, which are ChangeNotifiers.
    // So, it never needs to notify its direct children based on its own properties changing.
    return false;
  }
}

class AppManagersProvider extends StatefulWidget {
  final Widget child;

  const AppManagersProvider({super.key, required this.child});

  @override
  State<AppManagersProvider> createState() => _AppManagersProviderState();
}

class _AppManagersProviderState extends State<AppManagersProvider> {
  late CityListManager _cityListManager;
  late UnitSystemManager _unitSystemManager;
  late WeatherManager _weatherManager;
  late OpenWeatherService _openWeatherService;
  late SearchCitiesService _searchCitiesService;
  late LocationService _locationService;

  @override
  void initState() {
    super.initState();
    logger.d('AppManagersProviderState: Initializing managers...');

    _openWeatherService = OpenWeatherService();
    _searchCitiesService = SearchCitiesService();
    _locationService = LocationService(openWeatherService: _openWeatherService);

    _unitSystemManager = UnitSystemManager();
    _cityListManager = CityListManager(
      searchCitiesService: _searchCitiesService,
      locationService: _locationService,
    );
    _weatherManager = WeatherManager(
      weatherService: _openWeatherService,
      unitSystemManager: _unitSystemManager,
    );

    // Chain initializations to ensure dependencies are ready
    _unitSystemManager.initialized.then((_) {
      logger.d('AppManagersProviderState: UnitSystemManager initialized.');
      return _cityListManager.initialized; // Return future to chain
    }).then((_) {
      logger.d('AppManagersProviderState: CityListManager initialized.');
      // After CityListManager is ready, tell WeatherManager to fetch for initial cities
      _weatherManager.fetchWeatherForCities(_cityListManager.allCities).then((_) {
        logger.d('AppManagersProviderState: Initial weather fetched for all cities.');
      }).catchError((e) {
        logger.e('AppManagersProviderState: Error fetching initial weather: $e');
      });

      // Listen to CityListManager changes to update WeatherManager's tracked cities
      _cityListManager.addListener(_onCityListChanged);
    }).catchError((e) {
      logger.e('AppManagersProviderState: Error during manager initialization chain: $e');
    });
  }

  // Listener for CityListManager changes
  void _onCityListChanged() {
    logger.d('AppManagersProviderState: CityListManager changed. Updating WeatherManager tracked cities.');
    _weatherManager.fetchWeatherForCities(_cityListManager.allCities);
  }

  @override
  void dispose() {
    logger.d('AppManagersProviderState: Disposing managers...');
    _cityListManager.removeListener(_onCityListChanged); // Remove listener
    _cityListManager.dispose();
    _unitSystemManager.dispose();
    _weatherManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Provide managers using the custom AppManagers InheritedWidget
    return AppManagers(
      cityListManager: _cityListManager,
      unitSystemManager: _unitSystemManager,
      weatherManager: _weatherManager,
      child: widget.child,
    );
  }
}

// REMOVED: AppManagersContext extension // FIX: Removed as per instruction