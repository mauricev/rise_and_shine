// lib/screens/weather_screen.dart

import 'package:flutter/material.dart';
import 'package:rise_and_shine/managers/city_list_manager.dart';
import 'package:rise_and_shine/models/city.dart';
import 'package:rise_and_shine/models/city_display_data.dart';
import 'package:rise_and_shine/models/city_live_info.dart';
import 'package:rise_and_shine/providers/app_managers_provider.dart';
import 'package:rise_and_shine/screens/city_selection_screen.dart';
import 'package:rise_and_shine/consts/consts_ui.dart'; // Import the constants file
import 'dart:async'; // Import for Timer

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  // Local state to manage the "Added" button's momentary display
  bool _showAddedConfirmation = false;
  Timer? _addedConfirmationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.cityListManager.fetchAvailableCities();
    });
  }

  @override
  void dispose() {
    _addedConfirmationTimer?.cancel(); // Cancel timer to prevent memory leaks
    super.dispose();
  }

  // Method to handle adding a city to the saved list
  void _addCityToSavedList(City city) {
    final CityListManager manager = context.cityListManager;
    manager.addCityToSavedList(city); // Add the city via the manager

    setState(() {
      _showAddedConfirmation = true; // Show "Added" text
    });

    // Start a timer to hide the "Added" text after a brief moment
    _addedConfirmationTimer?.cancel(); // Cancel any existing timer
    _addedConfirmationTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showAddedConfirmation = false; // Hide "Added" text
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CityListManager manager = context.cityListManager;

    return Scaffold(
      appBar: AppBar(
        title: const Text(kWeatherScreenTitle),
        centerTitle: true,
        actions: const [],
      ),
      body: ListenableBuilder(
        listenable: manager,
        builder: (BuildContext context, Widget? child) {
          final City? selectedCity = manager.selectedCity;
          final bool isLoadingCities = manager.isLoadingCities;
          final String? citiesFetchError = manager.citiesFetchError;

          if (isLoadingCities) {
            return _buildLoadingCitiesState();
          } else if (citiesFetchError != null) {
            return _buildErrorFetchingCitiesState(citiesFetchError, manager);
          } else if (selectedCity == null) {
            return _buildNoCitySelectedState(context);
          }

          return StreamBuilder<List<CityDisplayData>>(
            stream: manager.citiesDataStream,
            builder: (BuildContext context, AsyncSnapshot<List<CityDisplayData>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return _buildWeatherErrorState(selectedCity, snapshot.error);
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildNoCityDataAvailableState();
              }

              final CityDisplayData? selectedCityDisplayData = snapshot.data!
                  .firstWhereOrNull((CityDisplayData cityDisplay) => cityDisplay.city == selectedCity);

              if (selectedCityDisplayData == null) {
                return _buildSelectedCityNotFoundState(selectedCity);
              }

              return _buildWeatherDisplay(selectedCityDisplayData, context);
            },
          );
        },
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
          Text(kLoadingCities), // Use constant
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
              '$kErrorFetchingCities $error', // Use constant
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => manager.fetchAvailableCities(),
              child: const Text(kRetryFetchCities), // Use constant
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
            kNoCitySelected, // Use constant
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (BuildContext context) => const CitySelectionScreen()),
              );
            },
            child: const Text(kSelectACity), // Use constant
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
              '$kErrorLoadingCities ${selectedCity.name}: $error', // Use constant
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
        kNoCityDataAvailableAfterFetch, // Use constant
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildSelectedCityNotFoundState(City selectedCity) {
    return Center(
      child: Text(
        '$kDataNotFoundForCity ${selectedCity.name}. $kPleaseSelectAnotherCity', // Use constants
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  // New private helper function to consolidate weather detail texts
  Widget _buildWeatherDetailsText(CityLiveInfo liveInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, // FIX: Ensure this column stretches
      children: [
        Text(
          '$kFeelsLike ${liveInfo.feelsLike!.toStringAsFixed(1)}°C', // Use constant
          style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
          textAlign: TextAlign.center, // Center text within the stretched column
        ),
        Text(
          '$kHumidity ${liveInfo.humidity!}%', // Use constant
          style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
          textAlign: TextAlign.center, // Center text within the stretched column
        ),
        Text(
          '$kWind ${liveInfo.windSpeed!.toStringAsFixed(1)} m/s ${liveInfo.windDirection}', // Use constant
          style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
          textAlign: TextAlign.center, // Center text within the stretched column
        ),
        Text(
          '$kCondition ${liveInfo.condition ?? 'N/A'}', // Use constant
          style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
          textAlign: TextAlign.center, // Center text within the stretched column
        ),
        Text(
          '$kDescription ${liveInfo.description ?? 'N/A'}', // Use constant
          style: const TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWeatherDisplay(CityDisplayData selectedCityDisplayData, BuildContext context) {
    final CityListManager manager = context.cityListManager; // Access manager here for button logic
    final City selectedCity = selectedCityDisplayData.city;
    final bool isCityCurrentlySaved = manager.isCitySaved(selectedCity);

    // Define a consistent size for the button/text to prevent layout shifts
    const Size buttonSize = Size(80, 40); // Approximate size of the TextButton or "Added" text

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
                  Column( // This is the main content column
                    crossAxisAlignment: CrossAxisAlignment.stretch, // FIX: Ensure this column stretches
                    children: [
                      Text(
                        selectedCityDisplayData.city.name,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        selectedCityDisplayData.liveInfo.formattedLocalTime,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (selectedCityDisplayData.liveInfo.isLoading)
                        const CircularProgressIndicator(strokeWidth: 3)
                      else if (selectedCityDisplayData.liveInfo.error != null)
                        Column(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              '$kWeatherError ${selectedCityDisplayData.liveInfo.error!}', // Use constant
                              style: const TextStyle(color: Colors.red, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      else if (selectedCityDisplayData.liveInfo.temperatureCelsius != null)
                          Column(
                            children: [
                              Text(
                                _getWeatherEmoji(selectedCityDisplayData.liveInfo.weatherIconCode!),
                                style: const TextStyle(fontSize: 70),
                              ),
                              Text(
                                '${selectedCityDisplayData.liveInfo.temperatureCelsius!.toStringAsFixed(1)}°C',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildWeatherDetailsText(selectedCityDisplayData.liveInfo),
                            ],
                          )
                        else
                          const Text(kNoWeatherDataAvailable, style: TextStyle(fontSize: 16, color: Colors.grey)), // Use constant
                    ],
                  ),
                  // Positioned Add button inside the Card with Container for consistent sizing
                  Positioned(
                    top: 0,
                    right: 0,
                    child: ListenableBuilder(
                      listenable: manager, // Listen to manager for saved state changes
                      builder: (BuildContext context, Widget? child) {
                        // Re-check isCitySaved here to react to manager's state changes
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
                                  foregroundColor: Colors.blue.shade700, // Adjusted color for visibility on card
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero, // Remove default padding
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Shrink tap area
                                ),
                                child: const Text(kAddButton), // Use constant
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
                                  kAddedConfirmation, // Use constant
                                  style: TextStyle(
                                    color: Colors.green, // Indicate success
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        // Return a transparent Container with fixed size to maintain layout
                        return SizedBox(
                          width: buttonSize.width,
                          height: buttonSize.height,
                          child: Container(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Align(
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
              child: const Text(kCitiesButton, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Use constant
            ),
          ),
        ],
      ),
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
}