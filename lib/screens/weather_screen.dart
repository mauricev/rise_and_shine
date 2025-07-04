// lib/screens/weather_screen.dart

import 'package:flutter/material.dart';
import 'package:rise_and_shine/managers/city_list_manager.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_display_data.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'package:rise_and_shine/providers/app_managers_provider.dart';
import 'package:rise_and_shine/screens/city_selection_screen.dart';
import 'package:rise_and_shine/consts/consts_ui.dart';
import 'dart:async';
import 'package:logger/logger.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _showAddedConfirmation = false;
  Timer? _addedConfirmationTimer;

  late CityListManager _cityListManager;
  bool _didInitialFetch = false;

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTime,
    ),
  );

  @override
  void initState() {
    super.initState();
    _logger.d('WeatherScreen: initState called.');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitialFetch) {
      _cityListManager = context.cityListManager;
      _logger.d('WeatherScreen: didChangeDependencies called. Manager initialized.');
      _initializeManagerAndFetchCities(_cityListManager);
      _didInitialFetch = true;
    } else {
      _logger.d('WeatherScreen: didChangeDependencies called again, initial fetch already triggered.');
    }
  }

  Future<void> _initializeManagerAndFetchCities(CityListManager manager) async {
    _logger.d('WeatherScreen: _initializeManagerAndFetchCities started.');
    try {
      _logger.d('WeatherScreen: Awaiting manager.initialized...');
      await manager.initialized;
      _logger.d('WeatherScreen: manager.initialized completed.');

      if (mounted) {
        _logger.d('WeatherScreen: Widget is mounted. Calling manager.fetchAvailableCities()...');
        await manager.fetchAvailableCities();
        _logger.d('WeatherScreen: manager.fetchAvailableCities() completed.');
      } else {
        _logger.d('WeatherScreen: Widget NOT mounted after manager initialization. Skipping fetch.');
      }
    } catch (e) {
      _logger.e('WeatherScreen: Error initializing manager or fetching cities: $e');
    }
  }

  @override
  void dispose() {
    _logger.d('WeatherScreen: dispose called.');
    _addedConfirmationTimer?.cancel();
    super.dispose();
  }

  void _addCityToSavedList(City city) {
    _logger.d('WeatherScreen: _addCityToSavedList called for ${city.name}.');
    _cityListManager.addCityToSavedList(city);

    setState(() {
      _showAddedConfirmation = true;
    });

    _addedConfirmationTimer?.cancel();
    _addedConfirmationTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showAddedConfirmation = false;
        });
      }
    });
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(kWeatherScreenTitle),
      centerTitle: true,
      actions: const [],
    );
  }

  Widget _buildBodyContent(CityListManager manager) {
    return ListenableBuilder(
      listenable: manager,
      builder: (BuildContext context, Widget? child) {
        final City? selectedCity = manager.selectedCity;
        final bool isLoadingCities = manager.isLoadingCities;
        final String? citiesFetchError = manager.citiesFetchError;

        if (isLoadingCities && selectedCity == null && manager.allCitiesDisplayData.isEmpty) {
          _logger.d('WeatherScreen: ListenableBuilder: Showing initial loading state (Manager loading with no data).');
          return _buildLoadingCitiesState();
        } else if (citiesFetchError != null) {
          _logger.d('WeatherScreen: ListenableBuilder: Showing cities fetch error state.');
          return _buildErrorFetchingCitiesState(citiesFetchError, manager);
        } else if (selectedCity == null) {
          _logger.d('WeatherScreen: ListenableBuilder: No city selected, showing selection prompt.');
          return _buildNoCitySelectedState(context);
        }

        _logger.d('WeatherScreen: ListenableBuilder: Selected city is ${selectedCity.name}. Proceeding to StreamBuilder.');
        return StreamBuilder<List<CityDisplayData>>(
          stream: manager.citiesDataStream,
          builder: (BuildContext context, AsyncSnapshot<List<CityDisplayData>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData && manager.isLoadingCities) {
              _logger.d('WeatherScreen: StreamBuilder: ConnectionState.waiting and no data, manager still loading. Showing progress indicator.');
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              _logger.e('WeatherScreen: StreamBuilder: Snapshot has error: ${snapshot.error}');
              return _buildWeatherErrorState(selectedCity, snapshot.error);
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              _logger.d('WeatherScreen: StreamBuilder: No data or empty data. Checking further conditions.');
              if (!manager.isLoadingCities && manager.selectedCity == null) {
                _logger.d('WeatherScreen: StreamBuilder: Manager not loading, no selected city. Showing selection prompt.');
                return _buildNoCitySelectedState(context);
              }
              _logger.d('WeatherScreen: StreamBuilder: Showing no city data available state.');
              return _buildNoCityDataAvailableState();
            }

            final CityDisplayData? selectedCityDisplayData = snapshot.data!
                .firstWhereOrNull((CityDisplayData cityDisplay) => cityDisplay.city == selectedCity);

            if (selectedCityDisplayData == null) {
              _logger.d('WeatherScreen: StreamBuilder: Selected city data not found in snapshot.');
              return _buildSelectedCityNotFoundState(selectedCity);
            }
            return _buildMainWeatherCard(selectedCityDisplayData, manager);
          },
        );
      },
    );
  }

  Widget _buildCityName(String cityName) {
    return Text(
      cityName,
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.blueAccent,
      ),
      textAlign: TextAlign.center,
    );
  }

  // This helper is now only for styling, actual positioning is done in _buildMainWeatherCard
  Widget _buildLocalTime(String formattedLocalTime) {
    return Text(
      formattedLocalTime,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      textAlign: TextAlign.center, // This alignment will be overridden by Positioned
    );
  }

  Widget _buildWeatherStatus(CityLiveInfo liveInfo) {
    if (liveInfo.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Text(
          'Fetching weather…',
          style: TextStyle(
            fontSize: 20,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      );
    } else if (liveInfo.error != null) {
      return Column(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 40),
          const SizedBox(height: 8),
          Text(
            '$kWeatherError ${liveInfo.error!}',
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else if (liveInfo.temperatureCelsius != null) {
      return Column(
        children: [
          Text(
            _getWeatherEmoji(liveInfo.weatherIconCode!),
            style: const TextStyle(fontSize: 70),
          ),
          const SizedBox(height: 8),
          if (liveInfo.description != null)
            Text(
              liveInfo.description!,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8), // Reduced spacing here as description is now above
          Text(
            '${liveInfo.temperatureCelsius!.toStringAsFixed(1)}°C',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          _buildWeatherDetailsText(liveInfo),
        ],
      );
    } else {
      return const Text(kNoWeatherDataAvailable, style: TextStyle(fontSize: 16, color: Colors.grey));
    }
  }

  Widget _buildAddCityButton(City selectedCity, CityListManager manager) {
    const Size buttonSize = Size(80, 40);

    final bool isCityCurrentlySavedForButton = manager.isCitySaved(selectedCity);

    if (!isCityCurrentlySavedForButton && !_showAddedConfirmation) {
      return SizedBox(
        width: buttonSize.width,
        height: buttonSize.height,
        child: Align(
          alignment: Alignment.topRight,
          child: TextButton(
            onPressed: () => _addCityToSavedList(selectedCity),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(kAddButton),
          ),
        ),
      );
    } else if (_showAddedConfirmation) {
      return SizedBox(
        width: buttonSize.width,
        height: buttonSize.height,
        child: const Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(
              kAddedConfirmation,
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: buttonSize.width,
      height: buttonSize.height,
      child: Container(),
    );
  }

  Widget _buildMainWeatherCard(CityDisplayData selectedCityDisplayData, CityListManager manager) {
    final City selectedCity = selectedCityDisplayData.city;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Stack(
                children: [
                  // Main content column (city name, weather status)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCityName(selectedCityDisplayData.city.name),
                      const SizedBox(height: 24), // Increased spacing
                      _buildWeatherStatus(selectedCityDisplayData.liveInfo),
                    ],
                  ),
                  // Positioned Add City Button
                  _buildAddCityButton(selectedCity, manager),
                  // FIX: Positioned Local Time at lower-left
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0), // Adjust padding as needed
                      child: _buildLocalTime(selectedCityDisplayData.liveInfo.formattedLocalTime),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildBottomNavigationButton(context),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationButton(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: TextButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (BuildContext context) => const CitySelectionScreen()),
          );
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue.shade700,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(color: Colors.blue.shade300),
        ),
        child: const Text(kCitiesButton, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLoadingCitiesState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(kLoadingCities),
        ],
      ),
    );
  }

  Widget _buildErrorFetchingCitiesState(String error, CityListManager manager) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            Text(
              '$kErrorFetchingCities $error',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => manager.fetchAvailableCities(),
              child: const Text(kRetryFetchCities),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCitySelectedState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            kNoCitySelected,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (BuildContext context) => const CitySelectionScreen()),
              );
            },
            child: const Text(kSelectACity),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherErrorState(City selectedCity, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            Text(
              '$kErrorLoadingCities ${selectedCity.name}: $error',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCityDataAvailableState() {
    return const Center(
      child: Text(
        kNoCityDataAvailableAfterFetch,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildSelectedCityNotFoundState(City selectedCity) {
    return Center(
      child: Text(
        '$kDataNotFoundForCity ${selectedCity.name}. $kPleaseSelectAnotherCity',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildDetailText(String label, String value) {
    return Text(
      '$label $value',
      style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildWeatherDetailsText(CityLiveInfo liveInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailText(kFeelsLike, '${liveInfo.feelsLike!.toStringAsFixed(1)}°C'),
        _buildDetailText(kHumidity, '${liveInfo.humidity!}%'),
        _buildDetailText(kWind, '${liveInfo.windSpeed!.toStringAsFixed(1)} m/s ${liveInfo.windDirection}'),
      ],
    );
  }

  String _getWeatherEmoji(String iconCode) {
    if (iconCode.contains('01')) return '☀️';
    if (iconCode.contains('02')) return '🌤️';
    if (iconCode.contains('03') || iconCode.contains('04')) return '☁️';
    if (iconCode.contains('09') || iconCode.contains('10')) return '🌧️';
    if (iconCode.contains('11')) return '⛈️';
    if (iconCode.contains('13')) return '❄️';
    if (iconCode.contains('50')) return '🌫️';
    return '❓';
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('WeatherScreen: build called.');
    final CityListManager manager = _cityListManager;

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBodyContent(manager),
    );
  }
}